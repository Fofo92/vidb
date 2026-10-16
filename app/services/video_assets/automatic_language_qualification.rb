# frozen_string_literal: true

module VideoAssets
  # Uses fresh probes and the existing transactional batch checks; preserves existing qualifications.
  class AutomaticLanguageQualification
    def initialize(root: '/videos', observer: CatalogEnrichment::TechnicalObservation.new, volume_guard: nil)
      @root = Pathname.new(root).cleanpath
      @observer = observer
      @volume_guard = volume_guard || ReconciliationVolumeGuard.new(root: root)
    end

    def call(asset_id:, apply: false)
      asset = VideoAsset.find(asset_id)
      return { status: 'already_qualified', applied: false, video_asset_id: asset.id } if asset.language_version_id

      observed = observe_copy(asset)
      proposal = proposal_for(asset, observed)
      return { status: 'needs_review', applied: false, proposal: proposal } unless automatic?(proposal)

      evidence = manifest(asset, observed, proposal)
      LanguageBatch.new(evidence: evidence, observer: @observer).call(apply: apply).merge(proposal: proposal)
    end

    private

    def automatic?(proposal)
      proposal[:status] == 'candidate' &&
        (proposal[:suggested_version] == 'VF' || %w[single_audio_policy_v1 observed_multilingual_policy_v1
                                                    encoder_project_policy
                                                    declared_silent_work].include?(proposal[:basis]))
    end

    def observe_copy(asset)
      validate_copy!(asset)
      observed = @observer.call(asset.last_known_path)
      unless observed.dig(:technical_details, 'storage', 'uuid') == ReconciliationVolumeGuard::UUID
        raise ArgumentError, 'Observed copy is on a different volume'
      end

      observed
    end

    def validate_copy!(asset)
      @volume_guard.call
      path = Pathname.new(asset.last_known_path)
      valid = asset.status_present? && path.absolute? && path.to_s.start_with?("#{@root}/") &&
              path == path.cleanpath && path.realpath == path && File.lstat(path).file?
      raise ArgumentError, 'Copy must be a present regular file inside the expected root, without symlinks' unless valid
    end

    def proposal_for(asset, observed)
      fresh = asset.dup
      fresh.id = asset.id
      fresh.observed_at = observed.fetch(:observed_at)
      fresh.technical_details = asset.technical_details.merge(observed.fetch(:technical_details))
      fresh.technical_details['observed_at'] = observed.fetch(:observed_at).iso8601
      LanguageProposal.new(fresh).call
    end

    def manifest(asset, observed, proposal)
      copy = proposal.stringify_keys.merge('byte_size' => asset.byte_size,
                                           'observed_at' => observed.fetch(:observed_at).iso8601,
                                           'language_version' => proposal.fetch(:suggested_version))
      { 'format' => 'vidb.video_asset_language_batch', 'version' => 1,
        'decided_by' => 'vidb (politique automatique)', 'decided_on' => Date.current.iso8601,
        'storage_uuid' => observed.fetch(:technical_details).fetch('storage').fetch('uuid'),
        'source_report' => { 'basis' => 'automatic_language_policy_v3', 'manual_listening' => false },
        'copies' => [copy] }
    end
  end
end
