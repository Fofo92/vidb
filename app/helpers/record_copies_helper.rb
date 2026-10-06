# frozen_string_literal: true

module RecordCopiesHelper
  def record_copy_summary(record)
    @record_copy_trees ||= {}
    root_id = record.root_id || record.id
    tree, assets = @record_copy_trees[root_id] ||= copy_tree(root_id)
    branch = tree.select { |node| node.id == record.id || node.ancestor_ids.include?(record.id) }
    VideoAssets::DisplaySummary.new(record: record, records: branch, assets: assets)
  end

  private

  def copy_tree(root_id)
    tree = Record.find(root_id).subtree.to_a
    assets = VideoAsset.where(record_id: tree.map(&:id), status: 'present').includes(:medium, :language_version).to_a
    [tree, assets]
  end
end
