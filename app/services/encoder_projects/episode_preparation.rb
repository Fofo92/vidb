module EncoderProjects
  class EpisodePreparation
    def initialize(user:, url:)
      @user = user
      @url = url
    end

    def call(scope:, parameters:, series_id:)
      data = completion_data(scope['candidate'], parameters, series_id)
      snapshot = complete_snapshot(data)
      Record.transaction do
        lock_catalogue!
        candidate, root_id = creation_context(scope['candidate'], series_id)
        write(scope, parameters, candidate, root_id, snapshot)
      end
    end

    private

    def completion_data(candidate, parameters, series_id)
      return candidate['series_candidate'] if candidate&.key?('series_candidate')
      return unless parameters['complete_catalogue'] == '1'

      data = candidate&.fetch('catalogue_completion', nil)
      unless data && data.fetch('record_id').to_s == series_id.to_s
        raise ArgumentError, 'Relance la recherche pour confirmer le catalogue de cette série.'
      end

      data
    end

    def complete_snapshot(data)
      return unless data

      client = TmdbSeriesClient.new(cache_dir: Rails.root.join('tmp/catalogue-episodes'), refresh: true)
      CatalogEnrichment::TmdbSeriesSnapshot.new(client: client, series_id: data.fetch('tmdb_id'),
                                                include_specials: true).call.deep_stringify_keys
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
      complete_series(record.parent.parent, snapshot) if snapshot
      EpisodeBinding.new(user: @user, url: @url).call(scope.fetch('project'), record)
      record
    end

    def complete_series(root, snapshot)
      ids = CatalogueEpisodeLink.where(provider: 'tmdb', record_id: root.subtree.select(:id))
                                .distinct.pluck(:external_series_id)
      unless ids.all? { |id| id == snapshot.fetch('tmdb_series_id') }
        raise ArgumentError, 'La série possède une autre identité TMDB : vérifie ses liens catalogue.'
      end

      SeriesCatalogueCompletion.new(root: root, snapshot: snapshot).call
    end

    def create_episode(scope, candidate, root_id, enrichment)
      creator = EpisodeCreation.new(previous_title: candidate&.fetch('title', nil))
      creator.call(project: scope.fetch('project'), series_id: root_id, **enrichment.creation_values)
    end
  end
end
