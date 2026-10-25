module ReconciliationWorkbench
  # Shared review boundary: this service records scoped decisions, never applies catalogue or disk writes.
  class CaseReview
    DECISIONS = %w[approved deferred rejected].freeze

    def initialize(user:, parameters:)
      @user = user
      @queue = parameters.fetch(:queue, true)
      @axis = parameters[:axis]
      @decision = parameters[:decision]
      @token = parameters[:token]
      @ids = Array(parameters[:ids]).map(&:to_s).uniq
      @comment = parameters[:comment].to_s[0, 2000]
    end

    def call
      validate_request!
      fingerprints = reviewed_fingerprints

      ReconciliationCase.transaction do
        items = locked_items
        validate_items!(items, fingerprints)
        changed = items.count { |item| save_review(item) }
        run = queue_application(changed)
        { count: changed, decision: @decision, run_id: run&.id }
      end
    end

    private

    def reviewed_fingerprints
      fingerprints = ReviewScope.read(@token, axis: @axis)
      return fingerprints if (@ids - fingerprints.keys).empty?

      raise ArgumentError, 'Une proposition cochée ne figurait pas sur cette page.'
    end

    def validate_request!
      raise ArgumentError, 'Utilisateur authentifié requis.' unless @user&.persisted?
      raise ArgumentError, 'Axe inconnu.' unless %w[metadata disk].include?(@axis)
      raise ArgumentError, 'Décision inconnue.' unless DECISIONS.include?(@decision)
      return if @ids.size.between?(1, 30) && @ids.all? { |id| id.match?(/\A[1-9]\d*\z/) }

      raise ArgumentError, 'Coche de 1 à 30 propositions de la page.'
    end

    def locked_items
      ReconciliationCase.current.where(id: @ids, axis: @axis, status: %w[pending blocked])
                        .order(:fingerprint, :id).lock.to_a
    end

    def validate_items!(items, fingerprints)
      unless items.size == @ids.size && items.all? { |item| fingerprints[item.id.to_s] == item.fingerprint }
        raise ArgumentError, 'Les propositions ont changé ou ont déjà été appliquées ; actualise la page.'
      end
      return unless @decision == 'approved'

      validate_exclusive_choices!(items)
      return if items.all? { |item| approvable?(item) }

      raise ArgumentError, 'Un cas exige encore un arbitrage ou une mise à jour de sa proposition ; ouvre son détail.'
    end

    def validate_exclusive_choices!(items)
      groups = items.filter_map { |item| item.payload['exclusive_group'].presence }
      return if groups.size == groups.uniq.size

      raise ArgumentError, 'Choisis une seule fiche pour chaque projet.'
    end

    def approvable?(item)
      rule = Rules.fetch(item.rule_key)
      rule.version == item.rule_version && Rules.applicable?(item)
    rescue ArgumentError, KeyError
      false
    end

    def queue_application(changed)
      ReconciliationRun.create!(mode: 'apply', user: @user) if @queue && @decision == 'approved' && changed.positive?
    end

    def save_review(item)
      review = ReconciliationCaseReview.for(item).first_or_initialize
      desired = [item.fingerprint, @decision, @user.id, @comment]
      return if review.persisted? && review.attributes.values_at('fingerprint', 'decision', 'user_id',
                                                                 'comment') == desired

      history = review.history.dup
      history << review.previous_receipt if review.persisted?
      review.update!(reconciliation_case: item, fingerprint: item.fingerprint, user: @user,
                     decision: @decision, comment: @comment, history: history)
      review
    end
  end
end
