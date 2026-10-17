module ReconciliationWorkbench
  class CopyPreferenceAction
    def initialize(observer: CopyObservation.new)
      @observer = observer
    end

    def observe(payload)
      assets = current_assets(payload)
      inputs = @observer.inputs(assets)
      verify_snapshots!(payload.fetch('samples'), inputs)
      samples = @observer.measure(inputs)
      result = CopyComparison.new.call(samples)
      expected = payload.fetch('comparison')
      unless result['eligible'] && result['preferred_asset_id'] == expected['preferred_asset_id']
        raise ArgumentError, 'La comparaison des copies a changé'
      end

      samples
    end

    def call(item, samples)
      payload = item.payload
      assets = current_assets(payload)
      verify_snapshots!(payload.fetch('samples'), assets.map { |asset| { 'snapshot' => Snapshot.asset(asset) } })
      preferred = payload.fetch('comparison').fetch('preferred_asset_id')
      assets.each { |asset| select(asset, preferred, item) }
      @observer.verify!(samples)
      { preferred_asset_id: preferred, retained_asset_ids: assets.map(&:id), quality_assessed: false }
    end

    private

    def current_assets(payload)
      assets = VideoAsset.where(record_id: payload.fetch('record_id'), status: 'present').order(:id).to_a
      expected = payload.fetch('samples').map { |sample| sample.fetch('asset_id') }
      raise ArgumentError, 'Les copies disponibles ont changé' unless assets.map(&:id) == expected

      assets
    end

    def verify_snapshots!(expected, actual)
      return if Snapshot.digest(expected.map { |sample| sample.fetch('snapshot') }) ==
                Snapshot.digest(actual.map { |sample| sample.fetch('snapshot') })

      raise ArgumentError, 'Une copie a été modifiée depuis la proposition'
    end

    def select(asset, preferred, item)
      marker = { 'origin' => 'family_rule', 'rule_version' => Rules::PREFERENCE.version, 'case_id' => item.id,
                 'preferred' => asset.id == preferred, 'preferred_asset_id' => preferred,
                 'inputs_digest' => item.payload.fetch('inputs_digest'), 'quality_assessed' => false }
      asset.update!(technical_details: asset.technical_details.merge('copy_preference' => marker))
    end
  end
end
