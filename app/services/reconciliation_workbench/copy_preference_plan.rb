module ReconciliationWorkbench
  class CopyPreferencePlan
    def initialize(observer: CopyObservation.new)
      @observer = observer
    end

    def call
      ids = VideoAsset.where(status: 'present').group(:record_id).having('COUNT(*) > 1').pluck(:record_id)
      seen = Record.where(id: ids).find_each.filter_map { |record| propose(record)&.id }
      ReconciliationCase.where(rule_key: Rules::PREFERENCE.key).where.not(id: seen).update_all(active: false)
      { 'preference_proposals' => seen.size }
    end

    def propose(record)
      return unless eligible_record?(record)

      assets = record.video_assets.where(status: 'present').order(:id).to_a
      inputs = @observer.inputs(assets)
      digest = Snapshot.copy_inputs_digest(inputs)
      return if already_selected?(assets, digest)

      samples = @observer.measure(inputs)
      comparison = CopyComparison.new.call(samples)
      store(record, samples, comparison, digest)
    rescue StandardError => e
      store(record, [], { 'eligible' => false, 'reason' => e.message }, nil)
    end

    private

    def eligible_record?(record)
      %w[episode standalone_video].include?(record.record_kind) && record.broadcast_part_count == 1 &&
        !record.has_children? && record.hierarchy_placement_status == :consistent
    end

    def already_selected?(assets, digest)
      markers = assets.map { |asset| asset.technical_details.fetch('copy_preference', {}) }
      return true if markers.any? { |marker| marker['origin'] == 'manual' }

      markers.one? { |marker| marker['preferred'] == true } && markers.all? do |marker|
        marker['rule_version'] == Rules::PREFERENCE.version && marker['inputs_digest'] == digest
      end
    end

    def store(record, samples, comparison, digest)
      copies = record.video_assets.where(status: 'present').order(:id).pluck(:id, :last_known_path)
      payload = { 'record_id' => record.id, 'title' => record.complete_title, 'file_count' => copies.size,
                  'samples' => samples, 'comparison' => comparison, 'inputs_digest' => digest,
                  'copies' => copies,
                  'records' => [*record.ancestors.to_a, record].to_h { |item| [item.id.to_s, Snapshot.record(item)] } }
      publish(record, payload)
    end

    def publish(record, payload)
      item = CaseStore.propose(rule: Rules::PREFERENCE, key: "record:#{record.id}", payload: payload,
                               preserve_pending: true)
      unless item.payload.dig('comparison', 'eligible') || item.status == 'applied'
        item.update!(status: 'blocked', error: item.payload.dig('comparison', 'reason'))
      end
      item
    end
  end
end
