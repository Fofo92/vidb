# frozen_string_literal: true

module CatalogEnrichment
  # Revalidates the existing catalogue and paths before technical observation.
  class BroadcastPartImportPlan
    def initialize(evidence:)
      @evidence = evidence.deep_symbolize_keys
      @root = Record.find(@evidence.fetch(:root_record_id))
    end

    def call
      validate!
      @evidence.fetch(:pairs).flat_map { |pair| entries(pair) }
    end

    private

    def validate!
      raise ArgumentError, 'Unsupported part import' unless @evidence[:format] == 'vidb.broadcast_part_import'
      raise ArgumentError, 'Unsupported version' unless @evidence[:version] == 1
      raise ArgumentError, 'Expected root series' if @root.ancestry.present?
      raise ArgumentError, 'Incompatible root kind' unless %w[series undetermined].include?(@root.record_kind)

      pairs = @evidence.fetch(:pairs)
      unique = pairs.pluck(:record_id).uniq.size == pairs.size
      raise ArgumentError, 'Empty or duplicate episode batch' if pairs.empty? || !unique
    end

    def entries(pair)
      record = Record.find(pair.fetch(:record_id))
      validate_record!(record, pair)
      parts = pair.fetch(:parts)
      raise ArgumentError, 'Expected exactly two parts' unless parts.pluck(:part).sort == [1, 2]

      parts.map { |part| validated_entry(record, pair, part) }
    end

    def validate_record!(record, pair)
      valid = !record.has_children? && record.parent&.parent_id == @root.id &&
              record.parent.rank == pair.fetch(:season) && record.rank == pair.fetch(:episode)
      raise ArgumentError, "Catalogue placement changed: #{record.id}" unless valid
      raise ArgumentError, 'Incompatible episode kind' unless %w[episode undetermined].include?(record.record_kind)

      signature = pair.fetch(:expected_titles)
      current = { french_title: record.french_title, original_title: record.original_title }
      accepted = signature.merge(pair.fetch(:corrections, {}))
      raise ArgumentError, "Catalogue titles changed: #{record.id}" unless [signature, accepted].include?(current)
    end

    def validated_entry(record, pair, part)
      path = part.fetch(:path)
      validate_path!(path)
      parsed = BroadcastPartName.call(stem: File.basename(path, File.extname(path)), path: path)
      valid = parsed && parsed[:season] == pair[:season] && parsed[:part] == part[:part] &&
              parsed[:local_number] == ((2 * pair[:episode]) - 2 + part[:part])
      raise ArgumentError, "Part numbering changed: #{path}" unless valid

      part.merge(record_id: record.id, corrections: pair.fetch(:corrections, {}))
    end

    def validate_path!(path)
      directory = @evidence.fetch(:directory)
      valid = path.start_with?("#{directory}/") && Pathname.new(path).cleanpath.to_s == path &&
              %w[.mkv .m4v .avi].include?(File.extname(path).downcase)
      raise ArgumentError, 'Unsafe part path' unless valid
      raise ArgumentError, 'Recently modified file' if Time.iso8601(path_entry(path).fetch(:modified_at)) > 24.hours.ago
    end

    def path_entry(path)
      @evidence.fetch(:pairs).flat_map { |pair| pair.fetch(:parts) }.find { |part| part[:path] == path }
    end
  end
end
