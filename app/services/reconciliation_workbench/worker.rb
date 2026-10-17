module ReconciliationWorkbench
  class Worker
    def self.directory
      Pathname.new(ENV.fetch('VIDB_RECONCILIATION_WORKBENCH_DIR') do
        if Rails.env.production?
          '/srv/vidb/shared/reconciliation-workbench'
        else
          Rails.root.join('tmp/reconciliation-workbench').to_s
        end
      end)
    end

    def initialize(planner: Planner.new, executor: Executor.new, refresh: ObservationRefresh.new)
      @planner = planner
      @executor = executor
      @refresh = refresh
    end

    def poll
      directory = self.class.directory
      directory.mkpath
      File.open(directory.join('worker.lock'), File::RDWR | File::CREAT, 0o600) do |lock|
        return { busy: true } unless lock.flock(File::LOCK_EX | File::LOCK_NB)

        run = ReconciliationRun.where(status: %w[running queued]).order(:created_at, :id).first || automatic_run
        return { idle: true } unless run

        perform(run)
      end
    end

    def perform(run)
      run.update!(status: 'running', started_at: run.started_at || Time.current, error: nil)
      ReconciliationCase.where(status: 'running').update_all(status: 'pending')
      plan = prepare_plan
      run.update!(summary: run.summary.merge('plan' => plan))
      apply_approved(run) if run.mode == 'apply'
      run.update!(status: run.reload.stop_requested? ? 'stopped' : 'completed', finished_at: Time.current)
      run.summary
    rescue StandardError => e
      run.update!(status: 'failed', error: "#{e.class}: #{e.message}", finished_at: Time.current)
      { error: run.error }
    end

    private

    def prepare_plan
      plan = @planner.call
      return plan unless plan.fetch('known_copies', 0).positive?

      @refresh.call
      @planner.call
    end

    def apply_approved(run)
      metadata = apply_axis(run, 'metadata')
      return if run.reload.stop_requested?

      if metadata.positive?
        @refresh.call
        @planner.call
      end
      disk = apply_axis(run, 'disk')
      @refresh.call if disk.positive?
    end

    def automatic_run
      path = Planner.followup_path
      return unless path.file?

      latest = ReconciliationRun.order(:created_at, :id).first
      return if latest && (latest.status == 'stopped' || latest.created_at >= path.mtime)

      mode = ReconciliationRuleDecision.where(decision: 'approved').exists? ? 'apply' : 'refresh'
      ReconciliationRun.create!(mode: mode)
    end

    def apply_axis(run, axis)
      applied = 0
      axis_scope(run, axis).find_each do |item|
        break if run.reload.stop_requested?
        next unless item.permitted?

        status = @executor.call(item)
        applied += 1 if status == 'applied'
        category = item.rule_key == Rules::PREFERENCE.key ? 'preferences' : axis
        update_progress(run, category, status)
      end
      applied
    end

    def axis_scope(run, axis)
      scope = ReconciliationCase.current.where(axis: axis, status: %w[pending blocked])
      run.rule_key.present? ? scope.where(rule_key: run.rule_key) : scope
    end

    def update_progress(run, axis, status)
      summary = run.summary
      summary[axis] ||= { 'applied' => 0, 'blocked' => 0 }
      summary[axis][status] = summary[axis].fetch(status, 0) + 1
      run.update!(summary: summary)
    end
  end
end
