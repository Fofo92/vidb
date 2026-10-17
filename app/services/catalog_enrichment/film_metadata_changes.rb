# frozen_string_literal: true

require 'date'

module CatalogEnrichment
  class FilmMetadataChanges
    def call(record:, entry:, operation:)
      return { status: 'protected_changed' } unless unchanged?(record, entry.fetch('local'))
      return { status: 'protected_year_history' } if record.year_history.present?

      change = build(record, entry, operation)
      draft = record.dup
      draft.assign_attributes(change.fetch(:attributes))
      return change if draft.valid?

      { status: 'blocked_validation', errors: draft.errors.to_hash }
    end

    def unchanged?(record, local)
      columns = %w[french_title original_title year year_basis year_evidence abstract]
      current = record.attributes.slice(*columns)
      current['original_title'] = current['original_title'].to_s
      current['genres'] = record.genders.reload.map(&:name).sort
      expected = local.except('record_id')
      record.id == local.fetch('record_id') && record.record_kind_standalone_video? && current == expected &&
        record.year_basis == 'unknown' && record.year_evidence.blank?
    end

    private

    def build(record, entry, operation)
      year = checked_year(entry)
      names = record.genre_provenance.present? ? nil : proposed_genres(entry)
      evidence = year_evidence(entry, operation, year)
      { status: 'ready', attributes: { year: year.fetch('proposed'), year_basis: 'first_release',
                                       year_evidence: evidence },
        gender_ids: names&.map { |name| genre_id(name) }, target: target(entry, year, names),
        genre_review_required: entry['genre_review_required'] == true }
    end

    def target(entry, year, names)
      { year: year.fetch('proposed'), year_basis: 'first_release',
        genres: names || entry.fetch('local').fetch('genres') }
    end

    def year_evidence(entry, operation, year)
      entry.fetch('proposal').fetch('source').merge(
        'operation_id' => operation, 'policy' => 'initial_film_metadata_v1',
        'date' => year.fetch('date'), 'release_reference' => year.fetch('reference'),
        'identity' => entry.fetch('identity'), 'qualified_at' => Time.current.iso8601
      )
    end

    def checked_year(entry)
      validate_identity!(entry)
      year = entry.fetch('proposal').fetch('year')
      date = Date.iso8601(year.fetch('date'))
      unless valid_reference?(year, date) && valid_year?(entry, year, date)
        raise ArgumentError, 'Invalid first-release evidence'
      end

      year
    end

    def validate_identity!(entry)
      valid = entry['status'] == 'candidate' && entry.dig('identity', 'supported') == true &&
              entry.dig('proposal', 'source', 'external_id') == entry.dig('identity', 'tmdb_id')
      raise ArgumentError, 'Only supported initial candidates are permitted' unless valid
    end

    def valid_reference?(year, date)
      reference = year.fetch('reference')
      year['status'] == 'candidate' && year['year_basis'] == 'first_release' &&
        reference['policy'] == 'first_public_release_v1' &&
        reference.dig('selected', 'date') == date.iso8601 &&
        [1, 2, 3, 4, 6].include?(reference.dig('selected', 'type'))
    end

    def valid_year?(entry, year, date)
      old = entry.dig('local', 'year')
      year['current'] == old && date.year == year['proposed'] && date.year >= 1900 && date <= Date.current &&
        (old.nil? || (old - date.year).abs <= 2)
    end

    def proposed_genres(entry)
      proposal = entry.fetch('proposal').fetch('genres')
      return if entry['genre_review_required'] || proposal['status'] != 'candidate'

      names = proposal.fetch('proposed')
      valid = entry.dig('local', 'genres').empty? && names.uniq.size.between?(1, 2) && names == names.uniq.sort
      raise ArgumentError, 'Only missing genres may be populated' unless valid

      names
    end

    def genre_id(name)
      entries = Gender.where('LOWER(name) = ?', name.downcase).to_a
      raise ArgumentError, "Missing or ambiguous genre reference: #{name}" unless entries.one?

      entries.first.id
    end
  end
end
