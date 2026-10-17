require 'json'

module ReconciliationWorkbench
  class Planner
    def self.followup_path
      Pathname.new(ENV.fetch('VIDB_RECONCILIATION_FOLLOWUP_PATH') do
        if Rails.env.production?
          '/srv/vidb/shared/reconciliation-followup/current.json'
        else
          Rails.root.join('tmp/reconciliation-followup/current.json').to_s
        end
      end)
    end

    def initialize(root: '/videos')
      @root = root
    end

    def call(followup: JSON.parse(self.class.followup_path.read))
      @known_copies = 0
      source = followup.deep_symbolize_keys
      validate_format!(source)
      candidates = source.fetch(:entries).select { |entry| unique_candidate?(entry) }
      @candidate_counts = candidates.group_by { |entry| entry[:candidates].first[:record_id] }.transform_values(&:size)
      structures, seen = collect_cases(source, candidates)
      publish_structures(structures, seen)
      deactivate_obsolete(seen)
      summarize(source, seen)
    end

    private

    def summarize(source, seen)
      summary = { 'proposed' => seen.size, 'known_copies' => @known_copies,
                  'inventory_at' => source.fetch(:inventory_at),
                  'source_counts' => VideoAssets::BlockageSummary.new(followup: source).call[:counts] }
      summary.merge(CopyPreferencePlan.new.call)
    end

    def validate_format!(source)
      return if source[:format] == VideoAssets::ReconciliationFollowup::FORMAT && source[:version] == 1

      raise ArgumentError, 'Journal de rapprochement incompatible'
    end

    def unique_candidate?(entry)
      entry[:followup_status] == 'candidate' && entry.fetch(:candidates, []).one?
    end

    def collect_cases(source, candidates)
      structures = {}
      seen = candidates.filter_map do |entry|
        next unless VideoAssets::BlockageCategory.call(entry) == 'candidate'

        record = Record.find_by(id: entry[:candidates].first.fetch(:record_id))
        next unless record

        propose_entry(source, entry, record, structures)
      end
      [structures, seen]
    end

    def propose_entry(source, entry, record, structures)
      if eligible_disk?(entry, record)
        disk_case(source, entry, record)&.id
      else
        collect_structure(entry, record, structures)
      end
    end

    def collect_structure(entry, record, structures)
      return unless entry[:status] == 'episode_candidate' && entry[:title_evidence] == 'title_match'

      plan = StructurePlan.for(record)
      return unless plan

      structures[plan['record_id']] ||= plan
      structures[plan['record_id']]['paths'] << entry[:path]
      nil
    end

    def publish_structures(structures, seen)
      structures.each_value do |payload|
        payload['paths'].sort!.uniq!
        payload['file_count'] = payload['paths'].size
        seen << CaseStore.propose(rule: Rules::STRUCTURE, key: "root:#{payload['record_id']}", payload: payload,
                                  preserve_pending: true).id
      end
    end

    def deactivate_obsolete(seen)
      ReconciliationCase.where(rule_key: [Rules::DISK.key, Rules::STRUCTURE.key]).where.not(id: seen)
                        .update_all(active: false)
    end

    def eligible_disk?(entry, record)
      return false unless @candidate_counts.fetch(record.id, 0) == 1 && record.broadcast_part_count == 1
      return false unless %w[episode standalone_video].include?(record.record_kind) && !record.has_children?
      return false unless record.hierarchy_placement_status == :consistent

      entry[:status] == 'exact' || (entry[:status] == 'episode_candidate' && entry[:title_evidence] == 'title_match')
    end

    def disk_case(source, entry, record)
      stat = stable_file(entry[:path], entry)
      return unless stat
      return if known_copy?(record, entry[:path], stat)

      CaseStore.propose(rule: Rules::DISK, key: entry[:path], payload: disk_payload(source, entry, record, stat),
                        preserve_pending: true)
    rescue Errno::ENOENT, Errno::EACCES
      nil
    end

    def known_copy?(record, path, stat)
      known = VideoAsset.where(status: 'present', record_id: record.id, last_known_path: path, byte_size: stat.size)
                        .where('observed_at >= ?', stat.mtime).exists?
      @known_copies += 1 if known
      known
    end

    def stable_file(path, entry)
      return unless path.start_with?("#{@root}/") && Pathname.new(path).cleanpath.to_s == path
      return unless File.realpath(path) == path

      stat = File.lstat(path)
      return unless stat.file? && stat.size == entry[:size] && stat.mtime.to_i == Time.iso8601(entry[:modified_at]).to_i

      stat if stat.mtime < Time.current - 24.hours
    end

    def disk_payload(source, entry, record, stat)
      records = [*record.ancestors.to_a, record]
      { 'record_id' => record.id, 'title' => record.complete_title, 'path' => entry[:path], 'file_count' => 1,
        'identity' => VideoAssets::RelocationFileIdentity.call(stat).as_json,
        'records' => records.to_h { |item| [item.id.to_s, Snapshot.record(item)] },
        'source_inventory' => source.fetch(:source_inventory).as_json,
        'entry' => entry.merge(type: 'file', candidate: entry[:candidates].first).as_json }
    end
  end
end
