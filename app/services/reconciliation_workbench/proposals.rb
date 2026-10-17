require 'uri'

module ReconciliationWorkbench
  class Proposals
    def call(document)
      unless document['format'] == 'vidb.sourced_metadata_proposals' && document['version'] == 1
        raise ArgumentError, 'Format de propositions incompatible'
      end

      Record.transaction { document.fetch('proposals').map { |proposal| import(proposal) } }
    end

    private

    def import(proposal)
      record = Record.lock.find(proposal.fetch('record_id'))
      field = proposal.fetch('field')
      validate_proposal!(proposal, record, field)
      before = field == 'genres' ? record.genders.order(:name).pluck(:name) : record.public_send(field)
      mode = fillable?(record, field, before) ? 'fill' : 'replace'
      payload = proposal.merge('value' => normalize_value(field, proposal.fetch('value')), 'before' => before,
                               'title' => record.complete_title, 'file_count' => 0,
                               'records' => { record.id.to_s => Snapshot.record(record) })
      CaseStore.propose(rule: Rules.fetch("sourced_#{field}_#{mode}"), key: "record:#{record.id}:#{field}",
                        payload: payload)
    end

    def validate_proposal!(proposal, record, field)
      raise ArgumentError, 'Caractéristique non prise en charge' unless Rules::FIELDS.include?(field)

      validate_identity!(proposal, record)
      if field == 'year' && !%w[first_release production].include?(proposal['year_basis'])
        raise ArgumentError, 'Convention d’année requise'
      end

      validate_sources!(proposal.fetch('sources'))
    end

    def validate_identity!(proposal, record)
      unless proposal.fetch('identity').values_at('french_title', 'original_title') ==
             [record.french_title, record.original_title]
        raise ArgumentError, 'Identité à vérifier avant proposition'
      end
      return if proposal['reason'].is_a?(String) && proposal['reason'].present?

      raise ArgumentError, 'Justification requise'
    end

    def validate_sources!(sources)
      raise ArgumentError, 'Sources requises' unless sources.is_a?(Array) && sources.any?

      sources.each do |url|
        uri = URI.parse(url)
        next if uri.scheme == 'https' && uri.host.present? && uri.userinfo.nil?

        raise ArgumentError, 'Source HTTPS requise'
      end
    end

    def fillable?(record, field, value)
      return false unless value.blank?
      return !record.abstract_protected? if field == 'abstract'
      return record.genre_provenance.blank? if field == 'genres'
      return record.year_evidence.blank? if field == 'year'

      true
    end

    def normalize_value(field, value)
      case field
      when 'year' then integer(value)
      when 'country_id' then Country.find(integer(value)).id
      when 'language_version_id' then LanguageVersion.find(integer(value)).id
      when 'genres' then genre_names(value)
      else
        raise ArgumentError, 'Résumé vide' unless value.is_a?(String) && value.present?

        value
      end
    end

    def integer(value)
      unless value.is_a?(Integer) || (value.is_a?(String) && value.match?(/\A\d+\z/))
        raise ArgumentError,
              'Entier requis'
      end

      Integer(value)
    end

    def genre_names(value)
      raise ArgumentError, 'Liste de genres requise' unless value.is_a?(Array) && value.any?
      raise ArgumentError, 'Genre inconnu' unless Gender.where(name: value).pluck(:name).sort == value.uniq.sort

      value.uniq.sort
    end
  end
end
