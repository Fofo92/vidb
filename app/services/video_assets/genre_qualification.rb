# frozen_string_literal: true

module VideoAssets
  # Applies an already determined classification; it never moves files.
  class GenreQualification
    class Refused < StandardError; end

    def call(record:, names:, expected_names:)
      names = normalized_names(names)
      validate_input!(record, expected_names)
      record.with_lock(requires_new: true) { qualify_locked(record, names, expected_names) }
    end

    private

    def qualify_locked(record, names, expected_names)
      raise Refused, 'Only standalone videos are supported' unless record.record_kind_standalone_video?

      before = record.genders.reload.map(&:name).sort
      return result(record, before, before, changed: false) if before == names.sort

      raise Refused, "Genres changed since review: #{before.inspect}" unless before == expected_names.sort

      record.genders = names.map { |name| find_genre(name) }
      record.touch
      result(record, before, names.sort, changed: true)
    end

    def validate_input!(record, expected_names)
      unless expected_names.is_a?(Array) && expected_names.all?(String)
        raise Refused, 'Expected genres must be an array of strings'
      end
      return if record.persisted? && !record.has_changes_to_save?

      raise Refused, 'A saved, unchanged record is required'
    end

    def find_genre(name)
      matches = Gender.where(name: name).limit(2).to_a
      raise Refused, "Ambiguous genre: #{name}" if matches.size > 1

      matches.first || Gender.create!(name: name)
    end

    def normalized_names(names)
      raise Refused, 'One or two genre names are required' unless valid_names?(names)

      normalized = names.map(&:strip)
      raise Refused, 'Duplicate or unsafe genre name' if invalid_names?(normalized)

      normalized
    end

    def valid_names?(names)
      names.is_a?(Array) && names.size.between?(1, 2) && names.all?(String)
    end

    def invalid_names?(names)
      names.uniq.size != names.size || names.any? { |name| unsafe_name?(name) }
    end

    def unsafe_name?(name)
      name.empty? || %w[. ..].include?(name) || name.match?(%r{[/\\\x00-\x1f]})
    end

    def result(record, before, after, changed:)
      { changed: changed, record_id: record.id, before: before, after: after }
    end
  end
end
