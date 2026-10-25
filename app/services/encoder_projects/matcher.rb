module EncoderProjects
  # The same scoped hierarchy matcher as disk reconciliation, before any output file exists.
  class Matcher
    def call(request)
      path = request.data.fetch('output_path')
      stem = File.basename(path, '.mkv')
      stem = stem.sub(/\A\d{1,3}\s*[-—–]\s*/, '') unless VideoAssets::ReconciliationReport::EPISODE_PREFIX.match?(stem)
      inventory = { format: 'vidb.video_library_inventory', version: 1, roots: ['/videos'], entries: [
        { type: 'file', path: path, relative_path: path.delete_prefix('/videos/'), extension: '.mkv', stem: stem }
      ] }
      records = Record.select(:id, :french_title, :original_title, :record_kind, :ancestry, :rank)
      VideoAssets::ReconciliationReport.new(inventory: inventory, records: records).call.fetch(:observations).sole
    end

    def self.qualified?(record)
      record && !record.has_children? && valid_placement?(record) && valid_kind?(record)
    end

    def self.valid_placement?(record)
      return false if record.has_parent? && record.parent.nil?

      record.hierarchy_placement_status == :consistent
    end

    def self.valid_kind?(record)
      return true if record.record_kind_standalone_video?

      parent = record.parent
      record.record_kind_episode? && parent&.record_kind_season? && parent.parent&.record_kind_series?
    end

    def self.certain?(observation)
      candidates = observation.fetch(:candidates, [])
      return false unless candidates.one?
      if candidates.first[:record_kind] == 'episode'
        return observation[:status] == 'episode_candidate' && observation[:title_evidence] == 'title_match'
      end

      %w[exact convention].include?(observation[:status])
    end
  end
end
