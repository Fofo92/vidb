module ReconciliationWorkbench
  # A case decision takes priority over an existing family rule, including after replanning.
  class Permission
    def self.call(item, lock: false)
      rule = Rules.fetch(item.rule_key)
      return false unless item.rule_version == rule.version && Rules.applicable?(item)

      review = (lock ? ReconciliationCaseReview.for(item).lock : ReconciliationCaseReview.for(item)).first
      return review.permits?(item) if review

      decisions = lock ? ReconciliationRuleDecision.lock : ReconciliationRuleDecision
      decisions.find_by(rule_key: item.rule_key, rule_version: item.rule_version)&.permits?(item) == true
    rescue ArgumentError, KeyError
      false
    end
  end
end
