# frozen_string_literal: true

require 'test_helper'

module VideoAssets
  class EpisodeNumberMatchingTest < ActiveSupport::TestCase
    setup do
      language = LanguageVersion.create!(short_name: 'NUM', long_name: 'Test numérotation')
      @series = Record.create!(french_title: 'Série test', language_version: language)
      @season = Record.create!(french_title: 'Saison 01', parent: @series, rank: 1, language_version: language)
      @episode = Record.create!(french_title: 'Pilote', parent: @season, rank: 1, language_version: language)
    end

    test 'a leading catalogue index does not change hierarchy matching' do
      result = match('Saison 01', '12 - S01 E01 - Pilote')
      assert_equal 'episode_candidate', result[:status]
      assert_equal [@episode.id], result[:candidates].pluck(:record_id)
    end

    test 'series name before numbering does not change title checking' do
      assert_equal 'episode_candidate', match('Saison 01', 'Série test S01 E01 - Pilote')[:status]
      assert_equal 'episode_title_conflict', match('Saison 01', 'Série test S01 E01 - Autre titre')[:status]
    end

    test 'a contradictory season is still blocked with a catalogue prefix' do
      assert_equal 'season_number_conflict', match('Saison 02', '12 - S01 E01 - Pilote')[:reason]
    end

    private

    def match(season, stem)
      EpisodeMatcher.new(Record.all).match(relative_path: "Série test/#{season}/#{stem}.mkv", stem: stem)
    end
  end
end
