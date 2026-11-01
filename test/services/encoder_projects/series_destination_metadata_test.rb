require 'test_helper'

class EncoderProjects::SeriesDestinationMetadataTest < ActiveSupport::TestCase
  Series = Struct.new(:french_title, :original_title, :year, :effective_genders, :effective_countries) do
    def record_kind_series?
      true
    end
  end
  Season = Struct.new(:rank, :parent) do
    def record_kind_season?
      true
    end
  end
  Episode = Struct.new(:rank, :parent) do
    def record_kind_episode?
      true
    end
  end

  test 'episode identification includes production countries and documentary genres from its series' do
    genre = Struct.new(:name).new('Documentaire')
    country = Struct.new(:long_name).new('France')
    series = Series.new('Les envahisseurs', 'Les envahisseurs', 2023, [genre], [country])
    episode = Episode.new(2, Season.new(1, series))

    metadata = EncoderProjects::RecordPresentation.episode_placement(episode)

    assert_equal ['Documentaire'], metadata.fetch('series_genres')
    assert_equal ['France'], metadata.fetch('series_countries')
    assert_equal 1, metadata.fetch('season_number')
    assert_equal 2, metadata.fetch('episode_number')
    assert_equal 2023, metadata.fetch('series_year')
  end
end
