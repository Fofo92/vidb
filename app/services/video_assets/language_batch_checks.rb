# frozen_string_literal: true

require 'time'

module VideoAssets
  class LanguageBatchChecks
    def initialize(evidence)
      @evidence = evidence
    end

    def manifest!
      valid = @evidence['format'] == 'vidb.video_asset_language_batch' && @evidence['version'] == 1 &&
              @evidence['decided_by'].present? && @evidence['decided_on'].present?
      copies = @evidence.fetch('copies')
      valid &&= copies.present? && copies.map { |copy| copy.fetch('video_asset_id') }.uniq.size == copies.size
      raise ArgumentError, 'Invalid language batch' unless valid
    end

    def copy!(asset, copy, observed)
      valid = asset.status_present? && asset.record_id == copy.fetch('record_id') &&
              asset.last_known_path == copy.fetch('path') && observed.fetch(:path) == copy.fetch('path') &&
              asset.byte_size == copy.fetch('byte_size') && observed.fetch(:byte_size) == copy.fetch('byte_size')
      valid &&= observed.fetch(:technical_details).dig('storage', 'uuid') == @evidence.fetch('storage_uuid')
      raise ArgumentError, "Copy or storage changed: #{asset.id}" unless valid

      unchanged_file!(copy)
      audio!(copy, observed)
    end

    def unchanged_file!(copy)
      stat = File.stat(copy.fetch('path'))
      valid = stat.file? && stat.size == copy.fetch('byte_size') &&
              stat.mtime <= Time.iso8601(copy.fetch('observed_at')) && stat.mtime <= Time.current - 24.hours
      raise ArgumentError, "File changed or too recent: #{copy.fetch('path')}" unless valid
    end

    def proposal!(asset, copy, observed)
      return if copy.fetch('basis') == 'pascal_confirmation'

      fresh = asset.dup
      fresh.technical_details = asset.technical_details.merge(observed.fetch(:technical_details))
      fresh.id = asset.id
      proposal = LanguageProposal.new(fresh).call
      valid = proposal[:status] == 'candidate' && proposal[:suggested_version] == copy.fetch('language_version')
      raise ArgumentError, "Language proposal changed: #{asset.id}" unless valid
    end

    private

    def audio!(copy, observed)
      languages = observed.fetch(:technical_details).fetch('streams').filter_map do |stream|
        [stream.fetch('tags', {})['language']] if stream['codec_type'] == 'audio'
      end.flatten
      return if languages == copy.fetch('declared_audio_languages')

      raise ArgumentError, "Audio tracks changed: #{copy.fetch('video_asset_id')}"
    end
  end
end
