# frozen_string_literal: true

# Carries one tab's search through record actions without a shared session filter.
class RecordSearchContext
  QUERY_FIELDS = %w[q filters page].freeze

  def self.issue(user:, query:)
    payload = { 'user_id' => user.id, 'query' => query.to_h.deep_stringify_keys.slice(*QUERY_FIELDS) }
    verifier.generate(payload, purpose: 'record_search')
  end

  def self.query(token, user:)
    return nil unless token.is_a?(String) && user

    payload = verifier.verified(token, purpose: 'record_search')
    return nil unless payload.is_a?(Hash) && payload['user_id'] == user.id && payload['query'].is_a?(Hash)

    remove_missing_tree(payload['query'].slice(*QUERY_FIELDS))
  end

  def self.remove_missing_tree(query)
    tree = query.dig('filters', 'tree_id')
    query['filters'].delete('tree_id') if tree.present? && !Record.exists?(id: tree)
    query
  end
  private_class_method :remove_missing_tree

  def self.verifier
    Rails.application.message_verifier('record-search-context')
  end
  private_class_method :verifier
end
