# frozen_string_literal: true

class RecordCopyRelinksController < ApplicationController
  before_action :load_asset

  def new
    @path = params.require(:path)
    operation = service
    @confirmation = operation.confirmation(@path)
    @detected_size = operation.detected_size
  rescue ArgumentError, SystemCallError => e
    redirect_to library_inventory_path, alert: e.message
  end

  def create
    service.call(params.require(:confirmation))
    redirect_to record_path(@record), notice: 'Référence de la copie actualisée.', status: :see_other
  rescue ArgumentError, SystemCallError => e
    redirect_to library_inventory_path, alert: e.message, status: :see_other
  end

  private

  def load_asset
    @record = Record.find(params[:record_id])
    @asset = @record.video_assets.find(params[:video_asset_id])
  end

  def service
    VideoAssets::CopyRelink.new(@asset, user: current_user)
  end
end
