# frozen_string_literal: true

class RecordCopyRemovalsController < ApplicationController
  before_action :load_copy

  def new
    @confirmation = removal.confirmation
  rescue VideoAssets::CopyRemoval::Error, VideoAssets::CopyRemovalBridge::Error => e
    return render :new, locals: { error: e.message }, status: :unprocessable_entity if inventory?

    redirect_to record_path(@record), alert: e.message
  end

  def create
    removal.call(params.require(:confirmation))
    redirect_to return_path, notice: 'Copie placée dans la corbeille. Son historique est conservé.',
                             status: :see_other
  rescue VideoAssets::CopyRemoval::Error, VideoAssets::CopyRemovalBridge::Error => e
    redirect_to return_path, alert: e.message, status: :see_other
  end

  private

  def inventory?
    params[:inventory] == '1'
  end
  helper_method :inventory?

  def return_path
    return record_path(@record) unless inventory?

    library_inventory_path(q: params[:q].to_s.first(100), page: [params[:page].to_i, 1].max)
  end
  helper_method :return_path

  def load_copy
    @record = Record.find(params[:record_id])
    @asset = @record.video_assets.find(params[:video_asset_id])
  end

  def removal
    VideoAssets::CopyRemoval.new(@asset, user: current_user)
  end
end
