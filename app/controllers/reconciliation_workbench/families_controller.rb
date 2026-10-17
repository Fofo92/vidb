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
      save_decision(rule)
      redirect_to reconciliation_workbench_path(axis: rule.axis), notice: 'Décision enregistrée pour cette famille.'
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
        ReconciliationRun.create!(mode: 'apply', user: current_user) if value == 'approved'
      end
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
