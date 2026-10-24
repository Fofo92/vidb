module ReconciliationWorkbench
  class ReviewScope
    PURPOSE = 'reconciliation-case-review'.freeze

    def self.issue(items, axis:)
      payload = { 'axis' => axis, 'cases' => items.to_h { |item| [item.id.to_s, item.fingerprint] } }
      verifier.generate(payload, purpose: PURPOSE, expires_in: 2.hours)
    end

    def self.read(token, axis:)
      payload = verifier.verified(token.to_s, purpose: PURPOSE)
      return payload.fetch('cases') if payload.is_a?(Hash) && payload['axis'] == axis && payload['cases'].is_a?(Hash)

      raise ArgumentError, 'La page a expiré ou son périmètre est invalide ; actualise les propositions.'
    end

    def self.verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
