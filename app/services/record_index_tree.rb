# frozen_string_literal: true

# Expand matches without one subtree query per matching root.
class RecordIndexTree
  def initialize(matched_ids)
    @matched_ids = matched_ids.to_set
  end

  def ids
    records = matching_tree_records
    children = records.group_by(&:parent_id)
    records.select(&:root?).sort_by(&:complete_title).flat_map { |root| branch(root, children) }
  end

  private

  def matching_tree_records
    records = Record.pluck(:id, :ancestry)
    roots = records.filter_map { |id, ancestry| root_id(id, ancestry) if @matched_ids.include?(id) }.to_set
    Record.where(id: records.filter_map { |id, ancestry| id if roots.include?(root_id(id, ancestry)) }).to_a
  end

  def branch(record, children)
    ordered = children.fetch(record.id, []).sort_by { |child| [child.rank || Float::INFINITY, child.complete_title, child.id] }
    [record.id] + ordered.flat_map { |child| branch(child, children) }
  end

  def root_id(id, ancestry)
    ancestry.to_s.split("/").reject(&:empty?).first&.to_i || id
  end
end
