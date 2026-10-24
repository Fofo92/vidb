module ReconciliationWorkbench
  class ApplicationProgress
    def call
      Rules.all.filter_map do |rule|
        decision = ReconciliationRuleDecision.find_by(rule_key: rule.key, rule_version: rule.version,
                                                      decision: 'approved')
        review = ReconciliationCaseReview.where(rule_key: rule.key, rule_version: rule.version, decision: 'approved')
                                         .order(updated_at: :desc).first
        next unless decision || review

        progress(rule, [decision&.updated_at, review&.updated_at].compact.max)
      end
    end

    private

    def progress(rule, approved_at)
      scope = ReconciliationCase.where(rule_key: rule.key, rule_version: rule.version)
      counts = scope.current.where(status: %w[pending running blocked]).select(&:permitted?)
                    .group_by(&:status).transform_values(&:size)
      applied = scope.where(status: 'applied')
      { rule: rule, counts: counts, approved_at: approved_at,
        applied: applied.count, last_applied_at: applied.maximum(:finished_at) }
    end
  end
end
