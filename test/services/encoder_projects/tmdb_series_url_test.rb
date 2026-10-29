require 'test_helper'

class EncoderProjects::TmdbSeriesUrlTest < ActiveSupport::TestCase
  test 'extracts a series identifier independently of its slug and language query' do
    %w[https://www.themoviedb.org/tv/42083-jos-phine-ange-gardien.
       https://themoviedb.org/tv/42083/ http://www.themoviedb.org/tv/42083?language=fr-FR].each do |url|
      assert_equal 42083, EncoderProjects::TmdbSeriesUrl.id(url)
    end
  end

  test 'extracts explicit episode numbers without replacing local numbering' do
    result = EncoderProjects::TmdbSeriesUrl.options('https://www.themoviedb.org/tv/42083-josephine/season/14/episode/2')
    assert_equal({ tmdb_series_id: 42083, tmdb_episode: { 'season' => 14, 'episode' => 2 } }, result)
    assert_empty EncoderProjects::TmdbSeriesUrl.options(nil)
  end

  test 'rejects films other hosts credentials and malformed URLs' do
    %w[https://www.themoviedb.org/movie/42083 https://example.org/tv/42083
       https://www.themoviedb.org.evil.org/tv/42083 https://user@www.themoviedb.org/tv/42083
       https://www.themoviedb.org/tv/0 https://www.themoviedb.org:444/tv/42083 invalid].each do |url|
      assert_raises(ArgumentError) { EncoderProjects::TmdbSeriesUrl.id(url) }
    end
  end
end
