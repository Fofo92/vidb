# frozen_string_literal: true

module RecordShowBreadcrumbsHelper
  def record_show_breadcrumbs(record, genres: '')
    nodes = record.ancestors.to_a + [record]
    prefix = record_show_breadcrumb_prefix(record, nodes, genres)
    prefix + nodes.map { |node| { label: record_show_breadcrumb_title(node), record: node } }
  end

  private

  def record_show_breadcrumb_prefix(record, nodes, genres)
    return [] if nodes.any? { |node| %w[series season episode].include?(node.record_kind) }

    labels = []
    labels << record_kind_label(record.record_kind) unless record.record_kind == 'undetermined'
    labels << genres if genres.present?
    labels.map { |label| { label: label, record: nil } }
  end

  def record_show_breadcrumb_title(node)
    return "Saison #{node.rank}" if node.record_kind == 'season' && node.rank.present?
    return "Collection #{node.complete_title}" if node.record_kind == 'collection'

    title = node.complete_title
    node.has_parent? && node.rank.to_i.positive? ? "#{node.rank} - #{title}" : title
  end
end
