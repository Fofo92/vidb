# frozen_string_literal: true

module VideoAssets
  class BatchCandidates
    def initialize(evidence)
      @evidence = evidence.deep_symbolize_keys
      validate_batch!
    end

    def entries
      @evidence.fetch(:entries)
    end

    def verify!
      inventory = @evidence.fetch(:source_inventory).merge(entries: entries)
      observations = ReconciliationReport.new(inventory: inventory).call.fetch(:observations)
      raise ArgumentError, 'Inventory entries changed' unless observations.size == entries.size

      entries.zip(observations).each { |entry, observed| verify_candidate!(entry, observed) }
    end

    private

    def validate_batch!
      valid = @evidence[:format] == 'vidb.video_asset_import_batch' && @evidence[:version] == 1 && entries.any?
      valid &&= unique_entries?
      raise ArgumentError, 'Invalid import batch' unless valid

      entries.each { |entry| validate_entry!(entry) }
    end

    def unique_entries?
      paths = entries.map { |entry| entry.fetch(:path) }
      records = entries.map { |entry| entry.fetch(:candidate).fetch(:record_id) }
      paths.uniq.size == entries.size && records.uniq.size == entries.size
    end

    def validate_entry!(entry)
      old_enough = Time.iso8601(entry.fetch(:modified_at)) < snapshot_time - 24.hours
      kind = entry.fetch(:candidate).fetch(:record_kind)
      valid = old_enough && %w[episode standalone_video].include?(kind) && eligible_status?(entry)
      valid &&= entry.fetch(:type) == 'file' && safe_path?(entry.fetch(:path))
      raise ArgumentError, "Ineligible batch entry: #{entry.fetch(:path)}" unless valid
    end

    def snapshot_time
      Time.iso8601(@evidence.fetch(:source_inventory).fetch(:generated_at))
    end

    def eligible_status?(entry)
      entry[:status] == 'exact' || (entry[:status] == 'episode_candidate' && entry[:title_evidence] == 'title_match')
    end

    def safe_path?(path)
      return false unless path.start_with?('/videos/') && Pathname.new(path).cleanpath.to_s == path

      path.split('/').none? { |part| part.start_with?('video_encoder_') || part.end_with?('_workspace') }
    end

    def verify_candidate!(entry, observed)
      candidates = observed.fetch(:candidates)
      valid = observed[:status] == entry[:status] && candidates.one?
      valid &&= candidates.first.slice(*entry.fetch(:candidate).keys) == entry.fetch(:candidate)
      raise ArgumentError, "Catalog match changed: #{entry.fetch(:path)}" unless valid
    end
  end
end
