# frozen_string_literal: true

module CatalogEnrichment
  class ConfirmedCompletion
    def initialize(evidence:, observer: FileObservation.new)
      @evidence = evidence
      @observer = observer
      validate_evidence!
    end

    def call(apply: false)
      observations = @evidence.fetch('confirmed_paths').map { |path| @observer.call(path) }
      root = Record.find(@evidence.fetch('record_id'))
      root.with_lock { complete(root, observations, apply) }
    end

    private

    def validate_evidence!
      unless @evidence['format'] == 'vidb.confirmed_episode_hierarchy' && @evidence['version'] == 1 &&
             @evidence['confirmed_by_viewing'] == true && @evidence['local_season_number'] == 1
        raise ArgumentError, 'Confirmed local season 1 evidence required'
      end

      validate_paths!
    end

    def validate_paths!
      paths = @evidence.fetch('confirmed_paths')
      titles = @evidence.fetch('episode_titles')
      valid = paths.length == titles.length && paths.uniq == paths && paths.each_with_index.all? do |path, index|
        File.basename(path) == "S01 E#{format('%02d', index + 1)} - #{titles[index]}.m4v"
      end
      raise ArgumentError, 'Confirmed paths do not match episode titles' unless valid
    end

    def complete(root, observations, apply)
      episodes = confirmed_episodes(root)
      metadata = metadata_for(root, episodes)
      changes = metadata.plan
      assets = episodes.zip(observations).map { |episode, observation| asset_for(episode, observation) }
      metadata.apply! if apply
      assets.each_with_index { |asset, index| update_asset!(asset, observations[index]) } if apply
      { applied: apply, record_id: root.id, metadata: changes, files: observations,
        assets: assets.map { |asset| { record_id: asset.record_id, video_asset_id: asset.id } },
        states: root.reload.state_counts, confirmed_evidence: @evidence }
    end

    def confirmed_episodes(root)
      report = ConfirmedHierarchy.new(
        record_id: root.id, series_title: @evidence.fetch('series_title'),
        episode_titles: @evidence.fetch('episode_titles')
      ).call
      raise ArgumentError, 'Confirmed hierarchy must already exist' unless report[:previous_status] == 'already_present'

      root.children.sole.children.lock.order(:rank, :id).to_a
    end

    def metadata_for(root, episodes)
      metadata = @evidence.fetch('accepted_metadata')
      ConfirmedMetadata.new(
        records: [root, root.children.sole, *episodes], episodes: episodes,
        countries: metadata.fetch('countries'), genres: metadata.fetch('genre_dictionary_names'),
        year: metadata.fetch('episode_production_year')
      )
    end

    def asset_for(episode, observation)
      asset = VideoAsset.where(status: 'present', last_known_path: observation.fetch(:path)).lock.first
      raise ArgumentError, "Path already belongs to record #{asset.record_id}" if asset && asset.record_id != episode.id

      asset || VideoAsset.new(record: episode, last_known_path: observation.fetch(:path))
    end

    def update_asset!(asset, observation)
      attributes = observation.slice(:byte_size, :duration_minutes, :observed_at, :container)
      asset.update!(attributes.merge(status: 'present'))
    end
  end
end
