require 'uri'

module ReconciliationReviewsHelper
  def consolidation_rule(item)
    ReconciliationWorkbench::Rules.fetch(item.rule_key)
  rescue ArgumentError
    nil
  end

  def consolidation_review_label(item)
    return 'Appliquée' if item.status == 'applied'

    review = ReconciliationCaseReview.for(item).first
    return 'À réexaminer : proposition modifiée' if review && review.fingerprint != item.fingerprint
    return 'Bloquée : à examiner' if item.status == 'blocked'
    return 'Règle approuvée, en attente' if review.nil? && item.permitted?

    { 'approved' => 'Validée, en attente', 'deferred' => 'À revoir',
      'rejected' => 'Écartée' }.fetch(review&.decision, 'À examiner')
  end

  def consolidation_links(item)
    sources = Array(item.payload['sources']) + Array(item.payload['source_urls'])
    sources.select do |url|
      uri = URI.parse(url.to_s)
      uri.scheme == 'https' && uri.host.present? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end.uniq
  end

  def consolidation_page_path(number)
    reconciliation_workbench_reviews_path(axis: @axis, state: @state, q: @query, tree_id: @tree_id, page: number)
  end
end
