module RecordHierarchyPlacement
  extend ActiveSupport::Concern

  included do
    validate :validate_new_hierarchy_placement
  end

  ALLOWED_PARENT_KINDS_BY_RECORD_KIND = {
    "undetermined" => %w[undetermined series season],
    "standalone_video" => %w[undetermined],
    "series" => [],
    "season" => %w[undetermined series],
    "episode" => %w[undetermined series season]
  }.freeze

  class_methods do
    def allowed_parent_kinds_for_hierarchy(record_kind)
      ALLOWED_PARENT_KINDS_BY_RECORD_KIND.fetch(
        record_kind.to_s,
        []
      )
    end

    def allowed_record_kinds_for_new_hierarchy(parent: nil)
      record_kinds.keys.reject do |record_kind|
        candidate = new(record_kind: record_kind)
        candidate.parent = parent

        candidate.hierarchy_placement_status == :inconsistent
      end
    end
  end

  def hierarchy_placement_status
    return root_hierarchy_placement_status if root?
    return :inconsistent unless valid_parent_kinds_for_record_kind
                                .include?(parent.record_kind)
    return :undetermined if undetermined_hierarchy_context?

    :consistent
  end

  def allows_new_hierarchy_children?
    self.class.allowed_record_kinds_for_new_hierarchy(parent: self).any?
  end

  def allows_root_hierarchy_placement?
    self.class
        .allowed_record_kinds_for_new_hierarchy
        .include?(record_kind)
  end

  private

  def validate_new_hierarchy_placement
    return unless new_record? || parent_id != parent_id_in_database
    return unless hierarchy_placement_diagnosable?
    return unless hierarchy_placement_status == :inconsistent

    errors.add(
      :parent_id,
      "ne permet pas ce placement pour la nature du contenu"
    )
  end

  def hierarchy_placement_diagnosable?
    return false unless self.class.record_kinds.key?(record_kind)
    return false if errors[:ancestry].any?
    return false if has_parent? && parent.nil?

    true
  end

  def root_hierarchy_placement_status
    case record_kind
    when "undetermined"
      :undetermined
    when "standalone_video", "series"
      :consistent
    else
      :inconsistent
    end
  end

  def undetermined_hierarchy_context?
    record_kind_undetermined? || parent.record_kind_undetermined?
  end

  def valid_parent_kinds_for_record_kind
    self.class.allowed_parent_kinds_for_hierarchy(record_kind)
  end
end
