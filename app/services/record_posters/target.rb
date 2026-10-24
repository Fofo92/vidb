# frozen_string_literal: true

module RecordPosters
  # Resolve only persisted, scoped identities; never search by title or guess a film id from a TV id.
  class Target
    def self.call(record)
      new(record).call
    end

    def initialize(record)
      @record = record
    end

    def call
      case @record.record_kind
      when 'series' then series_target(@record)
      when 'season' then season_target
      when 'standalone_video' then explicit_target('movie', 'tmdb_movie_id')
      when 'collection' then explicit_target('collection', 'tmdb_collection_id')
      end
    end

    private

    def series_target(series)
      ids = CatalogueEpisodeLink.where(provider: 'tmdb', record_id: series.descendants.select(:id))
                                .distinct.pluck(:external_series_id)
      evidence = series.year_evidence.to_h
      ids << evidence['tmdb_series_id']
      ids << evidence['external_series_id'] if evidence['provider'] == 'tmdb'
      ids.concat(url_ids(evidence, 'tv'))
      id = unique_id(ids)
      { type: 'tv', id: id } if id
    end

    def season_target
      return unless @record.parent&.record_kind_series?

      target = series_target(@record.parent)
      numbers = CatalogueEpisodeLink.where(provider: 'tmdb', record_id: @record.descendants.select(:id))
                                    .distinct.pluck(:external_season_number)
      number = unique_id(numbers)
      target.merge(season: number) if target && number
    end

    def explicit_target(type, key)
      evidence = @record.year_evidence.to_h
      id = unique_id([evidence[key]] + url_ids(evidence, type))
      { type: type, id: id } if id
    end

    def url_ids(evidence, type)
      [evidence['url'], evidence['source']].filter_map do |url|
        match = url.to_s.match(%r{\Ahttps://www\.themoviedb\.org/#{type}/([1-9]\d*)(?:[/?].*)?\z})
        match[1] if match
      end
    end

    def unique_id(values)
      ids = values.compact.map(&:to_s).uniq
      ids.first.to_i if ids.one? && ids.first.match?(/\A[1-9]\d*\z/)
    end
  end
end
