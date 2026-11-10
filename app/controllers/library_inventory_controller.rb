# frozen_string_literal: true

class LibraryInventoryController < ApplicationController
  def show
    @snapshot = VideoAssets::InventorySnapshot.new.call
    assets = VideoAsset.includes(:record).to_a
    @issues = VideoAssets::InventoryReview.new(snapshot: @snapshot,
                                               assets: assets.reject(&:status_deleted?)).call
    @duplicates = RecordDuplicateReview.new(assets: assets).call
    filter_results
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
