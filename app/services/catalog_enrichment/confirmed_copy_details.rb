# frozen_string_literal: true

module CatalogEnrichment
  class ConfirmedCopyDetails
    def initialize(evidence:, observer: TechnicalObservation.new)
      @evidence = evidence
      @observer = observer
      validate_evidence!
    end

    def call(apply: false)
      observations = @evidence.fetch('copies').map { |copy| @observer.call(copy.fetch('path')) }
      VideoAsset.transaction do
        plans = @evidence.fetch('copies').zip(observations).map { |copy, observed| plan(copy, observed) }
        plans.each { |asset, attributes| asset.update!(attributes) } if apply
        { applied: apply, copies: plans.map { |asset, attributes| attributes.merge(video_asset_id: asset.id) } }
      end
    end

    private

    def validate_evidence!
      valid = @evidence['format'] == 'vidb.confirmed_copy_details' && @evidence['version'] == 1 &&
              @evidence['confirmed_by'].present? && @evidence['confirmed_on'].present?
      copies = @evidence.fetch('copies')
      valid &&= copies.any? && copies.map { |copy| copy.fetch('video_asset_id') }.uniq.size == copies.size
      raise ArgumentError, 'Invalid copy confirmation' unless valid
    end

    def plan(copy, observed)
      asset = VideoAsset.lock.find(copy.fetch('video_asset_id'))
      validate_copy!(asset, copy, observed)
      medium = Medium.find_by!(short_name: @evidence.fetch('medium'))
      language = LanguageVersion.find_by!(short_name: @evidence.fetch('language_version'))
      validate_assignment!(asset, medium, language)
      [asset, attributes(observed, medium, language)]
    end

    def attributes(observed, medium, language)
      attributes = observed.slice(:byte_size, :duration_minutes, :container, :observed_at)
      attributes.merge!(medium_id: medium.id, language_version_id: language.id,
                        technical_details: details(observed))
    end

    def validate_copy!(asset, copy, observed)
      valid = asset.status_present? && asset.record_id == copy.fetch('record_id') &&
              asset.last_known_path == copy.fetch('path') && observed.fetch(:path) == copy.fetch('path') &&
              observed.fetch(:byte_size) == copy.fetch('byte_size') && asset.byte_size == copy.fetch('byte_size')
      storage = observed.fetch(:technical_details).fetch('storage')
      valid &&= storage.fetch('uuid') == @evidence.fetch('storage_uuid')
      raise ArgumentError, "Copy or storage changed: #{asset.id}" unless valid
    end

    def validate_assignment!(asset, medium, language)
      conflict = (asset.medium_id && asset.medium_id != medium.id) ||
                 (asset.language_version_id && asset.language_version_id != language.id)
      raise ArgumentError, "Conflicting copy qualification: #{asset.id}" if conflict
    end

    def details(observed)
      observed.fetch(:technical_details).merge(
        'measured_duration_seconds' => observed.fetch(:measured_duration_seconds),
        'observed_at' => observed.fetch(:observed_at).iso8601,
        'confirmation' => @evidence.slice('confirmed_by', 'confirmed_on', 'language_basis', 'medium_basis')
      )
    end
  end
end
