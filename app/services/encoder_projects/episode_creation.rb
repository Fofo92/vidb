module EncoderProjects
  class EpisodeCreation
    def initialize(previous_title: nil)
      @previous_title = previous_title
    end

    def call(project:, series_id:, title:, year:, source:)
      numbers = EpisodeRequest.new(project)
      validate!(title, year, source)
      Record.transaction do
        root = Record.lock.find(series_id)
        raise ArgumentError, 'Choisis une fiche qualifiée comme série' unless root.record_kind_series?

        season = season_for(root, numbers.season)
        episode_for(season, numbers, title.strip, year, source)
      end
    end

    private

    def validate!(title, year, source)
      raise ArgumentError, 'Titre requis (300 caractères maximum)' unless title.to_s.strip.length.between?(1, 300)
      raise ArgumentError, 'Année invalide' if year && !year.between?(1900, Date.current.year)
      return if source.to_s.empty? || source.to_s.match?(%r{\Ahttps://[^\s]+\z})

      raise ArgumentError, 'La référence doit être un lien HTTPS'
    end

    def season_for(root, rank)
      matches = root.children.where(rank: rank).to_a
      raise ArgumentError, 'Placement de la saison ambigu' if matches.size > 1

      season = matches.first
      raise ArgumentError, 'Le rang de saison est occupé par une autre nature' if season && !season.record_kind_season?
      return season if season
      if root.children.where(french_title: [format('Saison %02d', rank), "Saison #{rank}"]).exists?
        raise ArgumentError, 'Une saison de ce nom existe avec un autre rang : vérifie son placement'
      end

      root.children.create!(defaults.merge(french_title: format('Saison %02d', rank), record_kind: 'season',
                                           rank: rank))
    end

    def episode_for(season, numbers, title, year, source)
      matches = season.children.where(rank: numbers.episode).to_a
      raise ArgumentError, 'Plusieurs fiches occupent ce rang' if matches.size > 1

      existing = matches.first
      return reviewed_existing(existing, season, title) if existing

      raise ArgumentError, 'Ce titre existe déjà dans la saison' if season.children.where(french_title: title).exists?

      create_episode(season, numbers.episode, title, year, source)
    end

    def reviewed_existing(existing, season, title)
      existing.lock!
      valid = existing.record_kind_episode? && [title, @previous_title].compact.include?(existing.french_title)
      raise ArgumentError, 'Le rang est occupé par une autre fiche ou son titre a été modifié' unless valid

      rename_existing(existing, season, title) if existing.french_title != title
      existing
    end

    def rename_existing(existing, season, title)
      raise ArgumentError, 'Ce titre existe déjà dans la saison' if
        season.children.where.not(id: existing.id).where(french_title: title).exists?

      existing.update!(french_title: title)
    end

    def create_episode(season, rank, title, year, source)
      evidence = { 'url' => source, 'origin' => 'reviewed_encoder_episode' }
      attributes = { french_title: title, record_kind: 'episode', rank: rank, year: year,
                     year_basis: year ? 'first_release' : 'unknown', year_evidence: evidence }
      season.children.create!(defaults.merge(attributes))
    end

    def defaults
      { language_version: LanguageVersion.where(short_name: 'IND').sole,
        is_recorded: false, is_seen: false, is_available: false }
    end
  end
end
