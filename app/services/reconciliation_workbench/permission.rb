module ReconciliationWorkbench
  # A case decision takes priority over an existing family rule, including after replanning.
  class Permission
    def self.call(item, lock: false)
      rule = Rules.fetch(item.rule_key)
      return false unless item.rule_version == rule.version && Rules.applicable?(item)

      review = (lock ? ReconciliationCaseReview.for(item).lock : ReconciliationCaseReview.for(item)).first
      return review.permits?(item) if review

      family_permission?(item, rule, lock: lock)
    rescue ArgumentError, KeyError
      false
    end

    def self.family_permission?(item, rule, lock:)
      return false if rule.key == Rules::ENCODER_PROJECT.key

      decisions = lock ? ReconciliationRuleDecision.lock : ReconciliationRuleDecision
      decisions.find_by(rule_key: item.rule_key, rule_version: item.rule_version)&.permits?(item) == true
    end
  end
end
