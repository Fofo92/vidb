class ReconciliationCase < ApplicationRecord
  scope :current, -> { where(active: true) }
  validates :axis, inclusion: { in: %w[metadata disk] }
  validates :rule_key, :rule_version, :case_key, :fingerprint, presence: true
  validates :status, inclusion: { in: %w[pending running applied blocked superseded] }

  def permitted?
    ReconciliationRuleDecision.find_by(rule_key: rule_key, rule_version: rule_version)&.permits?(self) == true
  end
end
