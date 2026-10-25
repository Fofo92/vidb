module EncoderProjects
  class EpisodePreparation
    def initialize(user:, url:)
      @user = user
      @url = url
    end

    def call(scope:, parameters:, series_id:)
      snapshot = complete_snapshot(scope.dig('candidate', 'series_candidate'))
      Record.transaction do
        lock_catalogue!
        candidate, root_id = creation_context(scope['candidate'], series_id)
        write(scope, parameters, candidate, root_id, snapshot)
      end
    end

    private

    def complete_snapshot(data)
      return unless data

      client = TmdbSeriesClient.new(cache_dir: Rails.root.join('tmp/catalogue-episodes'), refresh: true)
      CatalogEnrichment::TmdbSeriesSnapshot.new(client: client, series_id: data.fetch('tmdb_id'),
                                                include_specials: true).call
    end

    def lock_catalogue!
      Record.connection.execute('SELECT pg_advisory_xact_lock(20261024, 2)') if
        Record.connection.adapter_name == 'PostgreSQL'
    end

    def creation_context(candidate, series_id)
      unless candidate&.key?('series_candidate')
        raise ArgumentError, 'Choisis une série' if series_id.blank?

        return [candidate, series_id]
      end
      root = SeriesCreation.new(candidate.fetch('series_candidate')).call
      [candidate.merge('series_id' => root.id), root.id]
    end

    def write(scope, parameters, candidate, root_id, snapshot)
      enrichment = EpisodeEnrichment.new(candidate: candidate, parameters: parameters, project: scope.fetch('project'))
      record = create_episode(scope, candidate, root_id, enrichment)
      enrichment.call(record)
      SeriesCatalogueCompletion.new(root: record.parent.parent, snapshot: snapshot).call if snapshot
      EpisodeBinding.new(user: @user, url: @url).call(scope.fetch('project'), record)
      record
    end

    def create_episode(scope, candidate, root_id, enrichment)
      creator = EpisodeCreation.new(previous_title: candidate&.fetch('title', nil))
      creator.call(project: scope.fetch('project'), series_id: root_id, **enrichment.creation_values)
    end
  end
end
