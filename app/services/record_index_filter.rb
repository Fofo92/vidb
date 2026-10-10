# frozen_string_literal: true

class RecordIndexFilter
  REFERENCES = { "country_id" => :countries, "gender_id" => :genders }.freeze
  attr_reader :tree, :matched_ids

  def initialize(parameters = {}, scope: Record.all)
    @parameters = parameters.to_h.stringify_keys
    @scope = scope
  end

  def call
    scope = tree_scope
    matches = criteria(scope)
    @matched_ids = matches.distinct.pluck(:id)
    if @parameters["display"] == "trees"
      context = @tree ? @tree.subtree : Record.all
      return context.in_order_of(:id, RecordIndexTree.new(@matched_ids).ids)
    end

    matches = matches.roots if @parameters["display"] == "roots"
    @matched_ids = matches.distinct.pluck(:id)
    matches.distinct
  end

  private

  def tree_scope
    return @scope if @parameters["tree_id"].blank?

    @tree = Record.find(integer(@parameters["tree_id"]))
    @scope.where(id: @tree.subtree.select(:id))
  end

  def criteria(scope)
    REFERENCES.each do |field, association|
      next if @parameters[field].blank?

      scope = scope.where(id: matching_reference_ids(association, integer(@parameters[field])))
    end
    scope = scalar_filters(scope)
    scope = copy_filter(scope, "language_version_id") if @parameters["language_version_id"].present?
    scope = copy_filter(scope, "medium_id") if @parameters["medium_id"].present?
    audit_filter(scope)
  end

  def scalar_filters(scope)
    scope = scope.where(record_kind: @parameters["record_kind"]) if @parameters["record_kind"].present?
    scope = scope.where(year: integer(@parameters["year"])) if @parameters["year"].present?
    scope
  end

  def reference_records
    @reference_records ||= Record.includes(:countries, :genders).to_a
  end

  def matching_reference_ids(association, id)
    values = RecordMetadataValues.new(records: reference_records)
    reference_records.select do |record|
      values.public_send(association, record).any? { |value| value.id == id }
    end.map(&:id)
  end

  def copy_filter(scope, field)
    id = integer(@parameters[field])
    present = VideoAsset.where(status: "present")
    copies = scope.where(id: present.where(field => id).select(:record_id))
    fallback = scope.where.not(id: present.select(:record_id))
    fallback = reference_filter(fallback, field, id)
    copies.or(fallback)
  end

  def reference_filter(scope, field, id)
    return scope.where(language_version_id: id) if field == "language_version_id"

    scope.where(id: Record.joins(:media).where(media: { id: id }).select(:id))
  end

  def audit_filter(scope)
    return scope if @parameters["missing"].blank? && @parameters["review"] != "1"

    rows = audit_rows
    rows = rows.select { |row| row[:review].any? } if @parameters["review"] == "1"
    scope.where(id: rows.map { |row| row[:id] })
  end

  def audit_rows
    rows = Rails.cache.fetch("record-metadata-filter-v2", expires_in: 1.minute) do
      RecordMetadataAudit.new.call[:records]
    end
    return rows if @parameters["missing"].blank?

    rows.select { |row| row[:missing].include?(@parameters["missing"].to_sym) }
  end

  def integer(value)
    Integer(value.to_s, 10)
  rescue ArgumentError
    raise ActiveRecord::RecordNotFound, "Critère invalide"
  end
end
