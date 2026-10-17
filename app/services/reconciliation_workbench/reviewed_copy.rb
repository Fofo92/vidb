module ReconciliationWorkbench
  module ReviewedCopy
    def self.verify!(payload, samples)
      review = payload.fetch('manual_review')
      expected = review.fetch('samples_digest')
      valid = Snapshot.digest(payload.fetch('samples')) == expected && Snapshot.digest(samples) == expected
      valid &&= samples.any? { |sample| sample['asset_id'] == review.fetch('preferred_asset_id') }
      raise ArgumentError, 'Les mesures ont changé depuis ton arbitrage ; un nouvel examen est nécessaire.' unless valid
    end

    def self.pending?(record)
      ReconciliationCase.current.where(rule_key: Rules::MANUAL_COPY.key, case_key: "record:#{record.id}",
                                       status: %w[pending running blocked]).any?(&:permitted?)
    end
  end
end
