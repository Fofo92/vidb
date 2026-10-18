module ReconciliationWorkbench
  class ApplicationProgress
    def call
      Rules.all.filter_map do |rule|
        decision = ReconciliationRuleDecision.find_by(rule_key: rule.key, rule_version: rule.version,
                                                      decision: 'approved')
        next unless decision

        progress(rule, decision)
      end
    end

    private

    def progress(rule, decision)
      scope = ReconciliationCase.where(rule_key: rule.key, rule_version: rule.version)
      counts = scope.current.where(status: %w[pending running blocked]).select do |item|
        decision.permits?(item)
      end.group_by(&:status).transform_values(&:size)
      applied = scope.where(status: 'applied')
      { rule: rule, counts: counts, approved_at: decision.updated_at,
        applied: applied.count, last_applied_at: applied.maximum(:finished_at) }
    end
  end
end
