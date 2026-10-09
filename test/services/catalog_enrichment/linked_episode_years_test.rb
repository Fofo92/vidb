# frozen_string_literal: true

require 'test_helper'

module CatalogEnrichment
  class LinkedEpisodeYearsTest < ActiveSupport::TestCase
    setup do
      language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
      @series = Record.create!(french_title: 'Série', record_kind: 'series', language_version: language)
      season = @series.children.create!(french_title: 'Saison 01', record_kind: 'season', language_version: language)
      @episode = season.children.create!(french_title: 'Épisode', record_kind: 'episode', language_version: language,
                                         year: 2019)
      @link = CatalogueEpisodeLink.create!(record: @episode, provider: 'tmdb', external_series_id: 75219,
                                           external_episode_id: 100, local_season_number: 1, local_episode_number: 1,
                                           external_season_number: 1, external_episode_number: 1,
                                           evidence: { 'first_air_date' => '2020-02-03' })
    end

    test 'preview leaves year and history unchanged' do
      report = LinkedEpisodeYears.new(root_record_id: @series.id).call
      assert_equal 2020, report[:episodes].first[:year]
      assert_equal 2019, @episode.reload.year
      assert_empty @episode.year_history
    end

    test 'application stores source and is idempotent' do
      2.times { LinkedEpisodeYears.new(root_record_id: @series.id, apply: true).call }
      assert_equal 2020, @episode.reload.year
      assert_equal 'first_release', @episode.year_basis
      assert_equal '2020-02-03', @episode.year_evidence['first_air_date']
      assert_equal 1, @episode.year_history.length
    end

    test 'missing dates leave legacy years alone' do
      @link.update!(evidence: {})
      report = LinkedEpisodeYears.new(root_record_id: @series.id, apply: true).call
      assert_equal 0, report[:total]
      assert_equal 2019, @episode.reload.year
    end

    test 'invalid dates abort without writing' do
      @link.update!(evidence: { 'first_air_date' => '2020-02-31' })
      assert_raises(Date::Error) { LinkedEpisodeYears.new(root_record_id: @series.id, apply: true).call }
      assert_equal 2019, @episode.reload.year
      assert_empty @episode.year_history
    end
  end
end
