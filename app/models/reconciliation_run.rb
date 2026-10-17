class ReconciliationRun < ApplicationRecord
  belongs_to :user, optional: true
  validates :status, inclusion: { in: %w[queued running completed stopped failed] }
  validates :mode, inclusion: { in: %w[refresh apply] }

  def terminal?
    %w[completed stopped failed].include?(status)
  end
end
