# frozen_string_literal: true

module ReconciliationRefreshNotification
  extend ActiveSupport::Concern

  included do
    after_commit :request_reconciliation_refresh
  end

  private

  def request_reconciliation_refresh
    VideoAssets::ReconciliationRefreshRequest.call
  end
end
