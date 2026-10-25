module EncoderProjects
  class SeriesCatalogueCompletion
    def initialize(root:, snapshot:)
      @root = root
      @snapshot = snapshot.deep_stringify_keys
      @language = LanguageVersion.where(short_name: 'IND').sole
      @metadata = CatalogueEpisodeMetadata.new(source_url: @snapshot.fetch('source_url'))
    end

    def call
      Record.transaction do
        @root.lock!
        @snapshot.fetch('series').fetch('seasons').each { |season| season_for(season.fetch('season_number')) }
        @snapshot.fetch('episodes').each { |row| complete_episode(row) }
      end
    end

    private

    def complete_episode(row)
      season = season_for(row.fetch('season_number'))
      record = episode_for(season, row)
      @metadata.call(record, row)
      attach_catalogue_link(record, row)
    end

    def season_for(number)
      matches = @root.children.where(rank: number).to_a
      raise ArgumentError, "Placement ambigu pour la saison #{number}" if matches.many?
      return checked(matches.sole, 'season') if matches.one?

      @root.children.create!(neutral.merge(record_kind: 'season', rank: number,
                                           french_title: format('Saison %02d', number)))
    end

    def episode_for(season, row)
      matches = season.children.where(rank: row.fetch('episode_number')).to_a
      raise ArgumentError, 'Plusieurs fiches occupent le même rang d’épisode' if matches.many?
      return checked_episode(matches.sole, row) if matches.one?

      season.children.create!(neutral.merge(record_kind: 'episode', rank: row.fetch('episode_number'),
                                            french_title: row['title_fr'].presence || row.fetch('title_original'),
                                            original_title: row['title_original']))
    end

    def neutral
      { language_version: @language, is_recorded: false, is_available: false, is_seen: false }
    end

    def checked(record, kind)
      record.lock!
      raise ArgumentError, 'Un autre type de fiche occupe le rang demandé' unless record.record_kind == kind

      record
    end

    def checked_episode(record, row)
      checked(record, 'episode')
      return record if catalogue_identity?(record, row)

      local = title_keys(record.attributes.values_at('french_title', 'original_title'))
      external = title_keys(row.values_at('title_fr', 'title_original'))
      unless local.intersect?(external)
        raise ArgumentError,
              "Numérotation ou titre à consolider pour la fiche #{record.id}"
      end

      record
    end

    def catalogue_identity?(record, row)
      CatalogueEpisodeLink.where(record: record, provider: 'tmdb', **link_values(row)).exists?
    end

    def title_keys(names)
      names.compact_blank.map { |name| name.parameterize.presence || name.unicode_normalize.downcase.squish }
    end

    def attach_catalogue_link(record, row)
      values = link_values(row)
      link = CatalogueEpisodeLink.find_or_initialize_by(record: record, provider: 'tmdb')
      return validate_link!(link, values) if link.persisted?

      evidence = @metadata.source(row).merge('reference_runtime_minutes' => row['reference_runtime_minutes'])
      link.assign_attributes(values.merge(evidence: evidence))
      link.save!
    end

    def link_values(row)
      { external_series_id: @snapshot.fetch('tmdb_series_id'), external_episode_id: row.fetch('tmdb_episode_id'),
        local_season_number: row.fetch('season_number'), external_season_number: row.fetch('season_number'),
        local_episode_number: row.fetch('episode_number'), external_episode_number: row.fetch('episode_number') }
    end

    def validate_link!(link, values)
      return if values.all? { |key, value| link[key] == value }

      raise ArgumentError, 'Identité externe existante différente'
    end
  end
end
