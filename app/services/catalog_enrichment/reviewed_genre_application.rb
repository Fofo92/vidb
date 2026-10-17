# frozen_string_literal: true

module CatalogEnrichment
  class ReviewedGenreApplication
    def call(record:, genres:, expected:, evidence:, operation_id:)
      validate_arguments!(genres, evidence, operation_id)
      record.with_lock do
        current = record.genders.reload.map(&:name).uniq.sort
        previous = record.genre_provenance
        replay = replay_status(previous, current, genres, evidence, operation_id)
        next replay if replay

        apply_if_unchanged(record, genres, expected, evidence, operation_id)
      end
    end

    private

    def validate_arguments!(genres, evidence, operation_id)
      unless genres.is_a?(Array) && genres.size.between?(1, 2) && genres == genres.uniq.sort
        raise ArgumentError, 'One or two sorted distinct genres required'
      end
      raise ArgumentError, 'Operation id required' unless operation_id.is_a?(String) && !operation_id.strip.empty?
      raise ArgumentError, 'Evidence required' unless valid_evidence?(evidence)
    end

    def valid_evidence?(evidence)
      evidence.is_a?(Hash) && evidence[:reason].is_a?(String) && evidence[:reason].present? &&
        evidence[:sources].is_a?(Array) && evidence[:sources].any?
    end

    def replay_status(previous, current, genres, evidence, operation_id)
      return { status: 'protected', applied: false } if previous.present? && previous['operation_id'] != operation_id
      return if previous.empty?

      unless previous['genres'] == genres && current == genres && previous['evidence'] == evidence.deep_stringify_keys
        raise ArgumentError, 'Operation id reused with different content'
      end

      { status: 'already_applied', applied: false }
    end

    def apply_if_unchanged(record, genres, expected, evidence, operation_id)
      names_match = record.genders.map(&:name).uniq.sort == expected.fetch(:genres)
      unless names_match && record.genre_provenance == expected.fetch(:provenance)
        return { status: 'changed_since_proposal', applied: false }
      end

      genders = Gender.where(name: genres).order(:name).to_a
      raise ArgumentError, 'Missing genre reference' unless genders.map(&:name).sort == genres

      write_reviewed_genres(record, genders, evidence, operation_id)
      { status: 'applied', applied: true }
    end

    def write_reviewed_genres(record, genders, evidence, operation_id)
      previous_genres = record.genders.map(&:name).uniq.sort
      receipt = { 'origin' => 'documented_review', 'protected' => true, 'operation_id' => operation_id,
                  'genres' => genders.map(&:name).sort, 'previous_genres' => previous_genres,
                  'evidence' => evidence.deep_stringify_keys, 'recorded_at' => Time.current.iso8601 }
      record.with_reviewed_genre_assignment do
        record.genders = genders
        record.update!(genre_provenance: receipt)
      end
    end
  end
end
