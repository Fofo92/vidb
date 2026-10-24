class ReconciliationCaseReview < ApplicationRecord
  belongs_to :reconciliation_case
  belongs_to :user

  validates :rule_key, :case_key, :fingerprint, presence: true
  validates :rule_version, numericality: { only_integer: true, greater_than: 0 }
  validates :decision, inclusion: { in: %w[approved deferred rejected] }
  validates :fingerprint, format: { with: /\A[0-9a-f]{64}\z/ }
  validate :matches_proposal

  def self.for(item)
    where(rule_key: item.rule_key, rule_version: item.rule_version, case_key: item.case_key)
  end

  def permits?(item)
    decision == 'approved' && fingerprint == item.fingerprint
  end

  def previous_receipt
    attributes.slice('fingerprint', 'decision', 'comment', 'user_id', 'reconciliation_case_id')
              .merge('reviewed_at' => updated_at.iso8601)
  end

  private

  def matches_proposal
    item = reconciliation_case
    return if item && [rule_key, rule_version, case_key, fingerprint] ==
                      [item.rule_key, item.rule_version, item.case_key, item.fingerprint]

    errors.add(:base, 'La décision doit correspondre à la proposition examinée')
  end
end
