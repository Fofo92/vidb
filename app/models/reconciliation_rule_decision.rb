class ReconciliationRuleDecision < ApplicationRecord
  belongs_to :user, optional: true
  validates :rule_key, :rule_version, presence: true
  validates :rule_key, uniqueness: { scope: :rule_version }
  validates :decision, inclusion: { in: %w[approved deferred rejected] }

  def permits?(item)
    rule = ReconciliationWorkbench::Rules.fetch(item.rule_key)
    decision == 'approved' && rule_version == rule.version &&
      (rule.recurring || case_fingerprints.include?(item.fingerprint))
  end
end
