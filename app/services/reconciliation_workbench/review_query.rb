module ReconciliationWorkbench
  class ReviewQuery
    STATES = %w[pending approved deferred rejected applied all].freeze
    JOIN = 'LEFT JOIN reconciliation_case_reviews case_reviews ON ' \
           'case_reviews.rule_key = reconciliation_cases.rule_key AND ' \
           'case_reviews.rule_version = reconciliation_cases.rule_version AND ' \
           'case_reviews.case_key = reconciliation_cases.case_key'.freeze

    def initialize(axis:, state:, query: nil, tree_id: nil)
      @axis = axis
      @state = STATES.include?(state) ? state : 'pending'
      @query = query.to_s.strip[0, 200]
      @tree_id = tree_id.presence
    end

    def call
      scope = ReconciliationCase.where(axis: @axis).joins(JOIN)
      scope = status_scope(scope)
      scope = scope.where('payload::text ILIKE ?', "%#{Record.sanitize_sql_like(@query)}%") if @query.present?
      scope = tree_scope(scope) if @tree_id
      scope.order('reconciliation_cases.id')
    end

    private

    def status_scope(scope)
      return scope.where(status: 'applied') if @state == 'applied'

      scope = scope.current.where(status: %w[pending blocked])
      return scope if @state == 'all'
      if @state == 'pending'
        return scope.where("case_reviews.id IS NULL OR (case_reviews.decision = 'approved' AND " \
                           'case_reviews.fingerprint <> reconciliation_cases.fingerprint)')
      end

      scope = scope.where(case_reviews: { decision: @state })
      @state == 'approved' ? scope.where('case_reviews.fingerprint = reconciliation_cases.fingerprint') : scope
    end

    def tree_scope(scope)
      tree = Record.find(@tree_id)
      ids = tree.subtree.pluck(:id).map(&:to_s)
      scope.where("payload ->> 'record_id' IN (?)", ids)
    end
  end
end
