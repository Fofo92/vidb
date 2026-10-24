require "test_helper"

class RecordPosters::EvidenceTest < ActiveSupport::TestCase
  def record(year: {}, abstract: {}, genre: {})
    Struct.new(:year_evidence, :abstract_provenance, :genre_provenance).new(year, abstract, genre)
  end

  test "reuses nested sources from existing catalogue enrichment" do
    item = record(year: { "sources" => [{ "provider" => "tmdb", "url" => "https://www.themoviedb.org/movie/123" }] },
                  abstract: { "source" => { "provider" => "tmdb", "url" => "https://www.themoviedb.org/movie/123" } })
    assert_equal [123], RecordPosters::Evidence.ids(item, "movie")
  end

  test "same numeric identifier cannot cross film and series namespaces" do
    item = record(year: { "sources" => [{ "url" => "https://www.themoviedb.org/tv/123" }] })
    assert_empty RecordPosters::Evidence.ids(item, "movie")
    assert_equal [123], RecordPosters::Evidence.ids(item, "tv")
  end

  test "keeps contradictory evidence visible and ignores unknown domains and bare ids" do
    item = record(year: { "tmdb_movie_id" => 124, "url" => "https://www.themoviedb.org/movie/123" },
                  genre: { "url" => "https://example.com/movie/999", "tmdb_id" => 999 })
    assert_equal [123, 124], RecordPosters::Evidence.ids(item, "movie").sort
  end
end
