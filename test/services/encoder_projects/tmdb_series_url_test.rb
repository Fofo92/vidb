require 'test_helper'

class EncoderProjects::TmdbSeriesUrlTest < ActiveSupport::TestCase
  test 'extracts a series identifier independently of its slug and language query' do
    %w[https://www.themoviedb.org/tv/42083-jos-phine-ange-gardien.
       https://themoviedb.org/tv/42083/ http://www.themoviedb.org/tv/42083?language=fr-FR].each do |url|
      assert_equal 42083, EncoderProjects::TmdbSeriesUrl.id(url)
    end
  end

  test 'rejects films other hosts credentials and episode URLs without changing the selected episode' do
    %w[https://www.themoviedb.org/movie/42083 https://example.org/tv/42083
       https://www.themoviedb.org.evil.org/tv/42083 https://user@www.themoviedb.org/tv/42083
       https://www.themoviedb.org/tv/42083/season/12/episode/11
       https://www.themoviedb.org/tv/0 https://www.themoviedb.org:444/tv/42083 invalid].each do |url|
      assert_raises(ArgumentError) { EncoderProjects::TmdbSeriesUrl.id(url) }
    end
  end
end
