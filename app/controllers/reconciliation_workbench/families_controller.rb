module ReconciliationWorkbench
  class FamiliesController < ApplicationController
    def show
      @rule = Rules.fetch(params[:id])
      @scope = scope(@rule)
      @total = @scope.count
      @scope_digest = Snapshot.digest(@scope.order(:fingerprint).pluck(:fingerprint))
      @page = [params[:page].to_i, 1].max
      @cases = @scope.order(:id).offset((@page - 1) * 30).limit(30)
      @decision = ReconciliationRuleDecision.find_by(rule_key: @rule.key, rule_version: @rule.version)
    end

    def decision
      rule = Rules.fetch(params[:id])
      receipt = save_decision(rule)
      redirect_to reconciliation_workbench_path(axis: rule.axis), notice: decision_notice(receipt)
    rescue ArgumentError => e
      redirect_to reconciliation_workbench_family_path(params[:id]), alert: e.message
    end

    def arbitrate
      raise ArgumentError, 'Famille incompatible' unless params[:id] == Rules::PREFERENCE.key

      choices = params.permit(choices: {}).fetch(:choices, {})
      count = CopyArbitration.new(user: current_user, choices: choices,
                                  scope_digest: params[:scope_digest], page: params[:page],
                                  comment: params[:comment]).call
      redirect_to reconciliation_workbench_path(axis: 'disk'),
                  notice: "#{count} choix confirmés ; application en attente."
    rescue ArgumentError => e
      redirect_to reconciliation_workbench_family_path(params[:id]), alert: e.message
    end

    private

    def save_decision(rule)
      ReconciliationRuleDecision.transaction do
        items = reviewed_scope(rule)
        value = params.require(:decision)
        validate_decision!(value, items)
        record = ReconciliationRuleDecision.find_or_initialize_by(rule_key: rule.key, rule_version: rule.version)
        record.update!(decision: value, user: current_user, comment: params[:comment],
                       case_fingerprints: rule.recurring ? [] : items.map(&:fingerprint))
        run = ReconciliationRun.create!(mode: 'apply', user: current_user) if value == 'approved'
        { value: value, count: items.size, run: run }
      end
    end

    def decision_notice(receipt)
      return 'Décision enregistrée pour cette famille.' unless receipt[:run]

      "Validation enregistrée : #{receipt[:count]} propositions autorisées. " \
        "Demande d’application n° #{receipt[:run].id} en attente du service. " \
        'Le suivi ci-dessous se met à jour automatiquement.'
    end

    def reviewed_scope(rule)
      items = scope(rule).order(:fingerprint).lock.to_a
      return items if params[:scope_digest] == Snapshot.digest(items.map(&:fingerprint))

      raise ArgumentError, 'Les propositions ont évolué ; relis le nouveau périmètre avant de valider.'
    end

    def validate_decision!(value, items)
      raise ArgumentError, 'Décision inconnue' unless %w[approved deferred rejected].include?(value)
      raise ArgumentError, 'Aucune proposition actuelle à approuver' if value == 'approved' && items.empty?
    end

    def scope(rule)
      ReconciliationCase.current.where(rule_key: rule.key, rule_version: rule.version, status: %w[pending blocked])
    end
  end
end
