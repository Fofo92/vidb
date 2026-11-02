# frozen_string_literal: true

class CopyRetirementsController < ApplicationController
  def new
    result = service.confirmation(params[:video_asset_ids])
    @assets = result.fetch(:assets)
    @confirmation = result.fetch(:token)
  rescue ArgumentError, SystemCallError => e
    redirect_to library_inventory_path, alert: e.message
  end

  def create
    operation = service
    assets = operation.call(params.require(:confirmation))
    destination = assets.one? ? record_path(assets.first.record_id) : library_inventory_path
    message = "#{assets.size} référence(s) retirée(s). Sauvegarde technique : #{operation.backup_path}"
    redirect_to destination, notice: message,
                             status: :see_other
  rescue ArgumentError, SystemCallError => e
    redirect_to library_inventory_path, alert: e.message, status: :see_other
  end

  private

  def service
    VideoAssets::MissingCopyRetirement.new(user: current_user)
  end
end
