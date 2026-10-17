module ReconciliationWorkbench
  class CandidateCopy
    def self.known?(record, path, stat)
      VideoAsset.where(status: 'present', record_id: record.id, last_known_path: path, byte_size: stat.size)
                .where('observed_at >= ?', stat.mtime).exists?
    end

    def self.stable_file(root, entry)
      path = entry.fetch(:path)
      return unless path.start_with?("#{root}/") && Pathname.new(path).cleanpath.to_s == path
      return unless File.realpath(path) == path

      stat = File.lstat(path)
      return unless stat.file? && stat.size == entry[:size] && stat.mtime.to_i == Time.iso8601(entry[:modified_at]).to_i

      stat if stat.mtime < Time.current - 24.hours
    end

    def self.input(payload)
      path = payload.fetch('path')
      { 'asset_id' => 'candidate', 'path' => path, 'identity' => payload.fetch('identity'),
        'modified_at' => File.mtime(path).iso8601(9),
        'snapshot' => { 'technical_details' => {} }, 'candidate' => payload }
    end

    def self.evidence(payload)
      { format: 'vidb.video_asset_import_batch', version: 1, medium: 'HD',
        storage_uuid: '3430606f-92bb-4da4-aaf2-36a3460bc298',
        source_inventory: payload.fetch('source_inventory'), selection_policy: 'approved_richer_copy_v2',
        entries: [payload.fetch('entry')] }
    end
  end
end
