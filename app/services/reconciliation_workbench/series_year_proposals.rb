require 'date'

module ReconciliationWorkbench
  class SeriesYearProposals
    def call(payload)
      episodes(payload) + seasons(payload)
    end

    private

    def episodes(payload)
      payload.fetch('operations').flat_map do |operation|
        next [] unless operation['existing_id']

        dated = operation.fetch('references').select { |reference| reference['airdate'].present? }
        propose(Record.find(operation['existing_id']), dated)
      end
    end

    def seasons(payload)
      payload.fetch('season_references', []).flat_map do |reference|
        candidates = Record.find(payload.fetch('record_id')).children.where(rank: reference.fetch('season')).to_a
        record = candidates.one? ? candidates.first : nil
        next [] unless record&.record_kind_season?

        propose(record, [reference])
      end
    end

    def propose(record, references)
      record.lock!
      return [] unless record.year.nil? && record.year_evidence.blank? && references.any?

      dates = references.map { |reference| checked_date(reference.fetch('airdate')) }.uniq
      raise ArgumentError, 'Dates de première diffusion contradictoires' unless dates.one?

      Proposals.new.call('format' => 'vidb.sourced_metadata_proposals', 'version' => 1,
                         'proposals' => [proposal(record, dates.first, references)])
    end

    def checked_date(value)
      date = Date.iso8601(value)
      return date if date.iso8601 == value && (1900..Date.current.year).cover?(date.year)

      raise ArgumentError, 'Date de première diffusion invalide'
    end

    def proposal(record, date, references)
      { 'record_id' => record.id, 'identity' => record.attributes.slice('french_title', 'original_title'),
        'field' => 'year', 'value' => date.year, 'year_basis' => 'first_release',
        'sources' => references.map { |reference| reference.fetch('url') }.uniq,
        'reason' => "Première diffusion originale documentée : #{date.iso8601}. Année absente uniquement." }
    end
  end
end
