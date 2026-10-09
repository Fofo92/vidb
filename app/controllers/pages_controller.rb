class PagesController < ApplicationController
  skip_before_action :authenticate_user!, only: :home

  def home
    @reconciliation_overview = VideoAssets::ReconciliationOverview.new.call if user_signed_in?
  end
end
