module RecordHierarchyPlacement
  extend ActiveSupport::Concern

  CONSISTENT_PARENT_KINDS_BY_RECORD_KIND = {
    "season" => %w[series],
    "episode" => %w[series season]
  }.freeze

  def hierarchy_placement_status
    return root_hierarchy_placement_status if root?
    return :inconsistent if impossible_hierarchy_relationship?
    return :undetermined if undetermined_hierarchy_context?

    if valid_parent_kinds_for_record_kind.include?(parent.record_kind)
      :consistent
    else
      :inconsistent
    end
  end

  private

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

  def impossible_hierarchy_relationship?
    parent.record_kind_standalone_video? ||
      parent.record_kind_episode? ||
      record_kind_series?
  end

  def undetermined_hierarchy_context?
    record_kind_undetermined? || parent.record_kind_undetermined?
  end

  def valid_parent_kinds_for_record_kind
    CONSISTENT_PARENT_KINDS_BY_RECORD_KIND.fetch(record_kind, [])
  end
end
