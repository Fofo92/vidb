# frozen_string_literal: true

class LibraryInventoryController < ApplicationController
  def show
    @snapshot = VideoAssets::InventorySnapshot.new.call
    assets = VideoAsset.includes(:record, :language_version).to_a
    @issues = VideoAssets::InventoryReview.new(snapshot: @snapshot,
                                               assets: assets.reject(&:status_deleted?)).call
    @duplicates = RecordDuplicateReview.new(assets: assets).call + disk_duplicate_groups(assets)
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
