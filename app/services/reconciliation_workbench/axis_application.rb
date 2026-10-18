module ReconciliationWorkbench
  class AxisApplication
    def initialize(executor:)
      @executor = executor
    end

    def call(run, axis)
      processed = []
      @applied = 0
      loop do
        found = apply_unseen(run, axis, processed)
        break unless found.positive? && !run.reload.stop_requested?
      end
      @applied
    end

    private

    def apply_unseen(run, axis, processed)
      before = processed.size
      scope(run, axis).where.not(id: processed).find_each do |item|
        break if run.reload.stop_requested?

        processed << item.id
        apply_one(run, axis, item) if item.permitted?
      end
      processed.size - before
    end

    def apply_one(run, axis, item)
      status = @executor.call(item)
      @applied += 1 if status == 'applied'
      category = Rules.copy_preference?(item.rule_key) ? 'preferences' : axis
      summary = run.summary
      summary[category] ||= { 'applied' => 0, 'blocked' => 0 }
      summary[category][status] = summary[category].fetch(status, 0) + 1
      run.update!(summary: summary)
    end

    def scope(run, axis)
      scope = ReconciliationCase.current.where(axis: axis, status: %w[pending blocked])
      run.rule_key.present? ? scope.where(rule_key: run.rule_key) : scope
    end
  end
end
