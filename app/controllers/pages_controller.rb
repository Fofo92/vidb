class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: :home

  def home
    return unless user_signed_in?

    @reconciliation_overview = VideoAssets::ReconciliationOverview.new.call
    @record_metadata_audit = Rails.cache.fetch("record-metadata-audit-v2", expires_in: 1.minute) do
      RecordMetadataAudit.new.call.except(:records)
    end
  end
end
