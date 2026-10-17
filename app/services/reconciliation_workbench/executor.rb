module ReconciliationWorkbench
  class Executor
    def initialize(disk: DiskAction.new, metadata: MetadataAction.new)
      @disk = disk
      @metadata = metadata
    end

    def call(item)
      return 'skipped' unless item.active? && item.permitted? && %w[pending blocked running].include?(item.status)

      item.update!(status: 'running', attempts: item.attempts + 1, started_at: Time.current, error: nil)
      observed = @disk.observe(item.payload) if item.axis == 'disk'
      apply_transaction(item, observed)
      'applied'
    rescue StandardError => e
      return 'applied' if item.persisted? && item.reload.status == 'applied'

      item.update!(status: 'blocked', error: "#{e.class}: #{e.message}", finished_at: Time.current)
      'blocked'
    end

    private

    def apply_transaction(item, observed)
      item.with_lock do
        verify_permission!(item)
        lock_catalog!
        Snapshot.verify!(item.payload.fetch('records'))
        before = item.payload.fetch('records').keys.to_h { |id| [id, Snapshot.record(Record.find(id))] }
        result = item.axis == 'disk' ? @disk.call(item.payload, observed) : @metadata.call(item)
        record_changes(item, before)
        item.update!(status: 'applied', result: result, finished_at: Time.current)
      end
    end

    def verify_permission!(item)
      decision = ReconciliationRuleDecision.lock.find_by!(rule_key: item.rule_key, rule_version: item.rule_version)
      return if item.active? && decision.permits?(item)

      raise ArgumentError, 'Validation retirée ou proposition remplacée'
    end

    def lock_catalog!
      return unless Record.connection.adapter_name == 'PostgreSQL'

      Record.connection.execute('LOCK TABLE records IN SHARE ROW EXCLUSIVE MODE')
      Record.connection.execute('LOCK TABLE video_assets IN SHARE ROW EXCLUSIVE MODE')
    end

    def record_changes(item, before)
      before.each do |id, previous|
        after = Snapshot.record(Record.find(id))
        next if Snapshot.digest(previous) == Snapshot.digest(after)

        ReconciliationRecordChange.create!(record_id: id, reconciliation_case: item,
                                           before_digest: Snapshot.digest(previous),
                                           after_digest: Snapshot.digest(after), after_snapshot: after)
      end
    end
  end
end
