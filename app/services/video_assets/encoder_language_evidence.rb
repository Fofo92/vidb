# frozen_string_literal: true

require 'json'
require 'time'

module VideoAssets
  # A companion project documents source roles, never completion of an export.
  class EncoderLanguageEvidence
    def initialize(asset)
      @asset = asset
      @path = Pathname.new(asset.last_known_path).sub_ext('.json')
    end

    def call
      return evidence('absent') unless @path.file?
      return evidence('copy_not_stable') unless stable_copy?

      document = JSON.parse(@path.read)
      return evidence('unsupported_project') unless supported?(document)

      project_evidence(document)
    rescue JSON::ParserError, KeyError, TypeError, ArgumentError, SystemCallError => e
      evidence('unreadable', error: e.class.name)
    end

    private

    def project_evidence(document)
      sources = used_sources(document)
      return evidence('incomplete_inspections') unless inspected?(sources)

      evidence('matched').merge(
        original_role_complete: complete_role?(sources, ['qaa']),
        french_role_complete: complete_role?(sources, %w[fra fre fr])
      )
    end

    def evidence(status, **details)
      { status: status, project_path: @path.to_s, policy: 'video_encoder.track_selection', **details }
    end

    def stable_copy?
      return false unless File.file?(@asset.last_known_path)

      stat = File.stat(@asset.last_known_path)
      observed_at = copy_observed_at
      return false if observed_at.blank? || @asset.byte_size.nil?

      stat.file? && @path.mtime <= stat.mtime && stat.size == @asset.byte_size &&
        stat.mtime <= Time.iso8601(observed_at) &&
        stat.mtime <= Time.current - 24.hours
    end

    def copy_observed_at
      @asset.observed_at&.iso8601 || @asset.technical_details['observed_at']
    end

    def supported?(document)
      document.is_a?(Hash) && document['format'] == 'video_encoder.trim_project' && document['version'] == 2
    end

    def used_sources(document)
      validate_collections!(document)
      ids = document.fetch('timeline').filter_map do |item|
        item.fetch('source_id') if item.fetch('type') == 'segment'
      end.uniq
      sources = document.fetch('sources').index_by { |source| source.fetch('id') }
      ids.map { |id| sources.fetch(id) }
    end

    def validate_collections!(document)
      %w[sources timeline].each do |key|
        collection = document.fetch(key)
        unless collection.is_a?(Array) && collection.all?(Hash)
          raise ArgumentError, "Invalid project collection: #{key}"
        end
      end
      ids = document.fetch('sources').map { |source| source.fetch('id') }
      raise ArgumentError, 'Duplicate source identifiers' unless ids.uniq == ids
    end

    def inspected?(sources)
      sources.present? && sources.all? { |source| valid_tracks?(source) }
    end

    def valid_tracks?(source)
      tracks = source.dig('inspection', 'audio_tracks')
      tracks.is_a?(Array) && tracks.all?(Hash)
    end

    def complete_role?(sources, languages)
      sources.all? do |source|
        source.fetch('inspection').fetch('audio_tracks').any? do |track|
          languages.include?(track['language'].to_s.downcase) && track['visual_impaired'] != true
        end
      end
    end
  end
end
