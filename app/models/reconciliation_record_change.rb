class ReconciliationRecordChange < ApplicationRecord
  belongs_to :reconciliation_case
  validates :record_id, :before_digest, :after_digest, :after_snapshot, presence: true
end
