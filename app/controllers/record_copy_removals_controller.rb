# frozen_string_literal: true

class RecordCopyRemovalsController < ApplicationController
  before_action :load_copy

  def new
    @confirmation = removal.confirmation
  rescue VideoAssets::CopyRemoval::Error, VideoAssets::CopyRemovalBridge::Error => e
    redirect_to record_path(@record), alert: e.message
  end

  def create
    removal.call(params.require(:confirmation))
    redirect_to record_path(@record), notice: 'Copie placée dans la corbeille. Son historique est conservé.',
                                      status: :see_other
  rescue VideoAssets::CopyRemoval::Error, VideoAssets::CopyRemovalBridge::Error => e
    redirect_to record_path(@record), alert: e.message, status: :see_other
  end

  private

  def load_copy
    @record = Record.find(params[:record_id])
    @asset = @record.video_assets.find(params[:video_asset_id])
  end

  def removal
    VideoAssets::CopyRemoval.new(@asset, user: current_user)
  end
end
