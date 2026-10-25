require 'test_helper'

class EncoderProjects::EpisodeTitlesTest < ActiveSupport::TestCase
  test 'foreign identical titles remain explicit while known French works avoid repetition' do
    assert_equal 'Boston (Boston)', EncoderProjects::EpisodeTitles.display('Boston', 'Boston', countries: ['États-Unis'])
    assert_equal 'Boston (Boston)', EncoderProjects::EpisodeTitles.display('Boston', 'Boston')
    assert_equal 'Un nouvel espoir', EncoderProjects::EpisodeTitles.display('Un nouvel espoir', 'Un nouvel espoir',
                                                                         countries: ['France'])
    assert_equal 'Le départ (Departure)', EncoderProjects::EpisodeTitles.display('Le départ', 'Departure')
    assert_equal 'Departure', EncoderProjects::EpisodeTitles.display('', 'Departure')
    assert_equal 'Boston (Boston)', EncoderProjects::EpisodeTitles.display('Boston (Boston)', 'Boston')
  end

  test 'a concordant source supplies the original title without changing the French title' do
    wiki = { 'title' => 'Le départ', 'year' => 2025, 'series_id' => 1, 'season' => 2, 'episode' => 1 }
    tmdb = wiki.merge('original_title' => 'Departure', 'source' => { 'provider' => 'tmdb' })
    result = EncoderProjects::EpisodeTitles.enrich([wiki, tmdb]).first
    assert_equal 'Le départ', result['title']
    assert_equal 'Departure', result['original_title']
    assert_equal 'tmdb', result.dig('original_title_source', 'provider')
  end

  test 'conflicting titles or another hierarchy never fill a missing original title' do
    wiki = { 'title' => 'Le départ', 'year' => 2025, 'series_id' => 1, 'season' => 2, 'episode' => 1 }
    foreign = wiki.merge('original_title' => 'Departure')
    [foreign.merge('series_id' => 2), foreign.merge('year' => 2024), foreign.merge('title' => 'Autre')].each do |other|
      assert_nil EncoderProjects::EpisodeTitles.enrich([wiki, other]).first['original_title']
    end
    assert_nil EncoderProjects::EpisodeTitles.enrich([wiki, foreign, foreign.merge('original_title' => 'Other')])
                             .first['original_title']
  end
end
