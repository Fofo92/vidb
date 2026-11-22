# frozen_string_literal: true

class LibraryInventoryController < ApplicationController
  before_action :load_inventory, only: %i[show preview_removals]

  def show; end

  def preview_removals
    ids = Array(params[:copy_ids]).map(&:to_i).uniq
    assets = @duplicates.flat_map { |group| group[:copies].values.flatten }.uniq(&:id)
    @removals = assets.select { |asset| ids.include?(asset.id) && asset.status_present? }
                      .map { |asset| removal_result(asset) { removal(asset).confirmation } }
    render_inventory
  end

  def remove_copies
    confirmations = params.permit(confirmations: {})[:confirmations] || {}
    @requested_count = confirmations.size
    @removals = VideoAsset.where(id: confirmations.keys).map do |asset|
      removal_result(asset) { removal(asset).call(confirmations[asset.id.to_s]) }
    end
    redirect_after_removals
  end

  def refresh
    if VideoAssets::ReconciliationRefreshRequest.path
      VideoAssets::ReconciliationRefreshRequest.call
      redirect_to library_inventory_path, notice: 'Actualisation demandée au service d’inventaire.'
    else
      redirect_to library_inventory_path, alert: 'Actualisation automatique non configurée dans cet environnement.'
    end
  end

  private

  def redirect_after_removals
    moved = @removals.count { |result| result[:error].nil? }
    missing = @requested_count - moved
    flash[:inventory_removal_result] = { 'moved' => moved, 'requested' => @requested_count, 'unconfirmed' => missing }
    redirect_to library_inventory_path(q: params[:q].to_s.first(100), page: [params[:page].to_i, 1].max,
                                       anchor: 'inventory_duplicates'), status: :see_other
  end

  def render_inventory
    respond_to do |format|
      format.turbo_stream do
        html = render_to_string(partial: 'library_inventory/duplicates', formats: [:html])
        render turbo_stream: turbo_stream.replace('inventory_duplicates', html)
      end
      format.html { render :show }
    end
  end

  def removal(asset)
    VideoAssets::CopyRemoval.new(asset, user: current_user)
  end

  def removal_result(asset)
    { asset: asset, confirmation: yield }
  rescue VideoAssets::CopyRemoval::Error, VideoAssets::CopyRemovalBridge::Error => e
    { asset: asset, error: e.message }
  end

  def load_inventory
    @snapshot = VideoAssets::InventorySnapshot.new.call
    assets = VideoAsset.includes(:record, :language_version).to_a
    @issues = VideoAssets::InventoryReview.new(snapshot: @snapshot,
                                               assets: assets.reject(&:status_deleted?)).call
    @duplicates = RecordDuplicateReview.new(assets: assets).call + disk_duplicate_groups(assets)
    filter_results
  end

  def disk_duplicate_groups(assets)
    by_record = assets.select(&:status_present?).group_by { |asset| [asset.record_id, episode_numbers(asset)] }
    by_record.values.filter_map do |copies|
      repeated = copies.group_by(&:broadcast_part_number).values.select(&:many?).flatten
      next if repeated.empty?

      record = repeated.first.record
      { records: [record], years: { record.id => record.year }, copies: { record.id => repeated }, disk: true }
    end
  end

  def episode_numbers(asset)
    filename = File.basename(asset.last_known_path.to_s)
    numbers = filename.scan(/(?<![[:alnum:]])S(\d+)[ ._-]*E(\d+)(?![[:alnum:]])/i)
    numbers.map { |season, episode| [season.to_i, episode.to_i] }.uniq.sort
  end

  def matches?(record)
    record.id.to_s == @query || record.complete_title.parameterize.include?(@query.parameterize)
  end

  def filter_results
    @query = params[:q].to_s.strip.first(100)
    if @query.present?
      @issues.select! { |row| matches?(row[:asset].record) }
      @duplicates.select! { |group| group[:records].any? { |record| matches?(record) } }
    end
    @issue_count = @issues.size
    @duplicate_count = @duplicates.size
    @page = [params[:page].to_i, 1].max
    @issues = @issues.slice((@page - 1) * 30, 30) || []
    @duplicates = @duplicates.slice((@page - 1) * 30, 30) || []
  end
end
