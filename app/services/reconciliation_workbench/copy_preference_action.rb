module ReconciliationWorkbench
  class CopyPreferenceAction
    def initialize(observer: CopyObservation.new)
      @observer = observer
    end

    def observe(payload)
      assets = current_assets(payload)
      inputs = @observer.inputs(assets)
      verify_snapshots!(registered_samples(payload), inputs)
      inputs << CandidateCopy.input(payload['candidate']) if payload['candidate']
      samples = @observer.measure(inputs)
      verify_comparison!(payload, samples)
      samples
    end

    def verify_comparison!(payload, samples)
      result = CopyComparison.new.call(samples)
      expected = payload.fetch('comparison')
      return if result['eligible'] && result['preferred_asset_id'] == expected['preferred_asset_id']

      raise ArgumentError, 'La comparaison des copies a changé'
    end

    def call(item, samples)
      payload = item.payload
      assets = current_assets(payload)
      verify_snapshots!(registered_samples(payload), assets.map { |asset| { 'snapshot' => Snapshot.asset(asset) } })
      preferred = payload.fetch('comparison').fetch('preferred_asset_id')
      preferred = import_candidate(payload, samples, assets, preferred) if payload['candidate']
      digest = Snapshot.copy_inputs_digest(@observer.inputs(assets))
      assets.each { |asset| select(asset, preferred, item, digest) }
      @observer.verify!(samples)
      { preferred_asset_id: preferred, retained_asset_ids: assets.map(&:id), quality_assessed: false }
    end

    private

    def import_candidate(payload, samples, assets, preferred)
      sample = samples.find { |input| input['asset_id'] == 'candidate' }
      CandidateImport.new(payload: payload['candidate'], sample: sample, assets: assets).call(apply: true)
      asset = VideoAsset.find_by!(status: 'present', last_known_path: sample.fetch('path'))
      assets << asset
      preferred == 'candidate' ? asset.id : preferred
    end

    def current_assets(payload)
      assets = VideoAsset.where(record_id: payload.fetch('record_id'), status: 'present').order(:id).to_a
      expected = registered_samples(payload).map { |sample| sample.fetch('asset_id') }
      raise ArgumentError, 'Les copies disponibles ont changé' unless assets.map(&:id) == expected

      assets
    end

    def verify_snapshots!(expected, actual)
      return if Snapshot.digest(expected.map { |sample| sample.fetch('snapshot') }) ==
                Snapshot.digest(actual.map { |sample| sample.fetch('snapshot') })

      raise ArgumentError, 'Une copie a été modifiée depuis la proposition'
    end

    def registered_samples(payload)
      payload.fetch('samples').reject { |sample| sample['asset_id'] == 'candidate' }
    end

    def select(asset, preferred, item, digest)
      marker = { 'origin' => 'family_rule', 'rule_version' => Rules::PREFERENCE.version, 'case_id' => item.id,
                 'preferred' => asset.id == preferred, 'preferred_asset_id' => preferred,
                 'inputs_digest' => digest, 'quality_assessed' => false }
      asset.update!(technical_details: asset.technical_details.merge('copy_preference' => marker))
    end
  end
end
