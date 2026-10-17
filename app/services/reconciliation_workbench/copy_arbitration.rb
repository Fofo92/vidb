module ReconciliationWorkbench
  class CopyArbitration
    def initialize(user:, choices:, scope_digest:, page: 1, comment: nil)
      @user = user
      @choices = choices.to_h.stringify_keys.except('')
      @scope_digest = scope_digest
      @page = [page.to_i, 1].max
      @comment = comment.to_s
    end

    def call
      ReconciliationCase.transaction do
        items = reviewed_items
        receipts = selected(items).map { |item, value| accept(item, value) }
        raise ArgumentError, 'Choisis au moins une copie ou conserve les cas à examiner.' if receipts.empty?

        authorize(receipts)
        ReconciliationRun.create!(mode: 'apply', rule_key: Rules::MANUAL_COPY.key, user: @user)
        receipts.size
      end
    end

    private

    def reviewed_items
      scope = ReconciliationCase.current.where(rule_key: Rules::PREFERENCE.key, rule_version: Rules::PREFERENCE.version,
                                               status: %w[pending blocked])
      items = scope.order(:fingerprint).lock.to_a
      unless @scope_digest == Snapshot.digest(items.map(&:fingerprint))
        raise ArgumentError, 'Les propositions ont évolué ; relis les copies avant de confirmer.'
      end

      items.sort_by(&:id).slice((@page - 1) * 30, 30) || []
    end

    def selected(items)
      available = items.index_by { |item| item.id.to_s }
      @choices.filter_map do |id, value|
        item = available[id]
        raise ArgumentError, 'Choix hors de la page examinée' unless item
        next if value == 'defer'

        [item, value]
      end
    end

    def accept(item, value)
      payload = item.payload.deep_dup
      selected = payload.fetch('samples', []).find { |sample| sample['asset_id'].to_s == value.to_s }
      unless payload.fetch('samples', []).size >= 2 && selected
        raise ArgumentError, 'Copie choisie absente des mesures examinées'
      end

      payload['manual_review'] = review(item, selected)
      receipt = CaseStore.propose(rule: Rules::MANUAL_COPY, key: item.case_key, payload: payload)
      item.update!(active: false)
      receipt
    end

    def review(item, selected)
      { 'preferred_asset_id' => selected.fetch('asset_id'), 'user_id' => @user.id,
        'reviewed_at' => Time.current.iso8601(9), 'comment' => @comment,
        'source_case_id' => item.id, 'source_fingerprint' => item.fingerprint,
        'samples_digest' => Snapshot.digest(item.payload.fetch('samples')) }
    end

    def authorize(receipts)
      rule = Rules::MANUAL_COPY
      decision = ReconciliationRuleDecision.lock.find_or_initialize_by(rule_key: rule.key, rule_version: rule.version)
      fingerprints = decision.case_fingerprints.to_a | receipts.map(&:fingerprint)
      decision.update!(decision: 'approved', user: @user, comment: @comment, case_fingerprints: fingerprints)
    end
  end
end
