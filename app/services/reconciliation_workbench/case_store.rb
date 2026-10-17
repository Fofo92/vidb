module ReconciliationWorkbench
  class CaseStore
    def self.propose(rule:, key:, payload:, preserve_pending: false)
      previous = guarded_pending(rule, key) if preserve_pending
      return previous if previous

      fingerprint = Snapshot.digest([rule.key, rule.version, payload])
      ReconciliationCase.transaction { persist(rule, key, payload, fingerprint) }
    end

    def self.persist(rule, key, payload, fingerprint)
      ReconciliationCase.where(rule_key: rule.key, case_key: key).where.not(fingerprint: fingerprint)
                        .update_all(active: false)
      item = ReconciliationCase.find_or_initialize_by(rule_key: rule.key, case_key: key, fingerprint: fingerprint)
      item.assign_attributes(axis: rule.axis, rule_version: rule.version, payload: payload) if item.new_record?
      item.active = true
      item.save!
      item
    end

    def self.guarded_pending(rule, key)
      item = ReconciliationCase.current.find_by(rule_key: rule.key, rule_version: rule.version,
                                                case_key: key, status: %w[pending running blocked])
      item if item&.permitted?
    end
  end
end
