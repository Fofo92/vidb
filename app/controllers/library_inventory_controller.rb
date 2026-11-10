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

  def metadata_review
    @metadata_query = params[:q].to_s.strip.first(100)
    @metadata_filters = { q: @metadata_query, genres: metadata_mode(:genres), pays: metadata_mode(:pays) }
    modes = { genders: @metadata_filters[:genres], countries: @metadata_filters[:pays] }
    groups = RecordMetadataInheritanceReview.new(modes: modes, include_aligned: @metadata_query.present?).call
    groups.select! { |branch| metadata_root_matches?(branch[:root]) } if @metadata_query.present?
    prepare_metadata_review(groups)
  end

  def update_metadata_forcing
    root = Record.find(params[:root_id])
    field = params[:field].to_s
    root.with_lock { update_forcing!(root, field, params[:mode]) }
    redirect_to metadata_review_library_inventory_path(q: root.id), notice: 'Règle de la branche enregistrée.'
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    redirect_to metadata_review_library_inventory_path(q: params[:root_id]), alert: e.message
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

  def update_forcing!(root, field, choice)
    attribute = RecordMetadataValues::MODE_ATTRIBUTES.stringify_keys[field]
    unless attribute && RecordMetadataValues.forcing_root?(root)
      raise ArgumentError, 'Série ou collection et champ requis.'
    end
    raise ArgumentError, 'Choisis un mode de transmission.' unless RecordMetadataValues::MODES.key?(choice)

    validate_parent_values!(root, field.to_sym) if choice == 'parent'
    root.update!(attribute => choice)
  end

  def validate_parent_values!(root, field)
    values = RecordMetadataValues.new(records: [root]).explicit(root, field).uniq(&:id)
    return if RecordMetadataValues.forceable?(field, values)

    raise ArgumentError, 'Renseigne les valeurs sur la fiche parente avant d’activer le forçage.'
  end

  def metadata_root_matches?(record)
    return record.id.to_s == @metadata_query if /\A[0-9]+\z/.match?(@metadata_query)

    matches?(record, @metadata_query)
  end

  def metadata_mode(parameter)
    params[parameter].presence_in(RecordMetadataValues::MODES.keys) || 'parent'
  end

  def prepare_metadata_review(groups)
    @metadata_total = groups.size
    @metadata_changed = groups.sum { |branch| branch[:changed_count] }
    @metadata_reviewed = groups.sum { |branch| branch[:rows].size }
    @metadata_branch = groups.first if groups.one? && @metadata_query.present?

    if @metadata_branch
      @metadata_rows = metadata_page(@metadata_branch[:rows])
    else
      @metadata_groups = metadata_page(groups.sort_by { |branch| branch[:root].complete_title })
    end
  end

  def metadata_page(items)
    @metadata_page_count = [(items.size + 29) / 30, 1].max
    @metadata_page = params[:page].to_i.clamp(1, @metadata_page_count)
    items.slice((@metadata_page - 1) * 30, 30) || []
  end

  def matches?(record, query = @query)
    record.id.to_s == query || record.complete_title.parameterize.include?(query.parameterize)
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
