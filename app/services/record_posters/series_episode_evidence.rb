# frozen_string_literal: true

module RecordPosters
  class SeriesEpisodeEvidence
    def self.key(title)
      title.to_s.unicode_normalize(:nfkd).downcase.gsub(/[^\p{Alnum}]/, '')
    end

    def initialize(client:, series_id:, language:)
      @client = client
      @series_id = series_id
      @language = language
    end

    def call(episodes)
      return false unless @language.to_s.match?(/\A[a-z]{2}\z/)

      episodes.group_by { |episode| episode.fetch('season') }.all? do |number, local|
        path = "tv/#{@series_id}/season/#{number}"
        french = @client.get(path)
        original = @client.get(path, language: @language)
        season_matches?(number, local, french, original)
      end
    end

    private

    def season_matches?(number, local, french, original)
      return false unless french['season_number'] == number && original['season_number'] == number

      translated = french.fetch('episodes')
      originals = original.fetch('episodes')
      return false unless [translated, originals].all? { |episodes| unique_numbers?(episodes) }

      local.all? { |episode| matched_episode?(episode, translated, originals) }
    end

    def matched_episode?(episode, translated, originals)
      row = translated.find { |item| item['episode_number'] == episode.fetch('rank') }
      source = originals.find { |item| item['episode_number'] == episode.fetch('rank') }
      row && source && episode_matches?(episode, row, source)
    end

    def unique_numbers?(episodes)
      numbers = episodes.map { |episode| episode.fetch('episode_number') }
      ids = episodes.map { |episode| episode.fetch('id') }
      numbers.uniq.size == episodes.size && ids.uniq.size == episodes.size
    end

    def episode_matches?(episode, french, original)
      return false unless french['id'] == original['id'] && french['air_date'] == original['air_date']
      return false unless year_matches?(french['air_date'], episode.fetch('year'))
      return false unless title_matches?(episode.fetch('french_title'), french['name'])

      original_title_matches?(episode, original['name'])
    end

    def original_title_matches?(episode, source)
      local = episode['original_title']
      numbers = [local, source].filter_map { |title| GenericEpisodeTitle.number(title) }
      return numbers.all? { |number| number == episode.fetch('rank') } if numbers.any?
      return true if local.blank? || source.blank?

      title_matches?(local, source)
    end

    def year_matches?(date, year)
      date.to_s.match?(/\A\d{4}-\d{2}-\d{2}\z/) && Date.iso8601(date).year == year
    rescue Date::Error
      false
    end

    def title_matches?(local, source)
      return false if local.blank? || !GenericEpisodeTitle.number(local).nil?
      return false unless GenericEpisodeTitle.number(source).nil?

      self.class.key(local) == self.class.key(source)
    end
  end
end
