# frozen_string_literal: true

module RecordPosters
  # Resolve only persisted, scoped identities; never search by title or guess a film id from a TV id.
  class Target
    def self.call(record)
      new(record).call
    end

    def self.series_ids(series)
      linked = CatalogueEpisodeLink.where(provider: 'tmdb', record_id: series.descendants.select(:id))
                                   .distinct.pluck(:external_series_id)
      (linked + Evidence.ids(series, 'tv')).compact.map(&:to_s).uniq
    end

    def initialize(record)
      @record = record
    end

    def call
      case @record.record_kind
      when 'series' then series_target(@record)
      when 'season' then season_target
      when 'standalone_video' then explicit_target('movie')
      when 'collection' then explicit_target('collection')
      end
    end

    private

    def series_target(series)
      id = unique_id(self.class.series_ids(series))
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

    def explicit_target(type)
      id = unique_id(Evidence.ids(@record, type))
      { type: type, id: id } if id
    end

    def unique_id(values)
      ids = values.compact.map(&:to_s).uniq
      ids.first.to_i if ids.one? && ids.first.match?(/\A[1-9]\d*\z/)
    end
  end
end
