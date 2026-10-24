require "test_helper"

class RecordPosters::FilmTargetTest < ActiveSupport::TestCase
  SUMMARY = "Thomas Pesquet voyage dans l’espace pour une mission scientifique extraordinaire à bord de la station internationale".freeze

  def record(year: 2018, evidence: {})
    Struct.new(:record_kind, :abstract, :year_evidence, :abstract_provenance, :genre_provenance, :attributes) do
      def record_kind_standalone_video? = true
    end.new("standalone_video", SUMMARY, evidence, {}, {},
            { "french_title" => "16 levers de soleil", "original_title" => "", "abstract" => SUMMARY, "year" => year })
  end

  def client_for(results, pages: 1)
    client = Object.new
    client.define_singleton_method(:search) do |title:, page:|
      { "results" => results, "page" => page, "total_pages" => pages }
    end
    client
  end

  def movie(id: 123, year: 2018, summary: SUMMARY)
    { "id" => id, "title" => "16 levers de soleil", "original_title" => "16 Sunrises",
      "release_date" => "#{year}-10-01", "overview" => summary }
  end

  test "automatically reuses the existing film identity comparison" do
    resolver = RecordPosters::FilmTarget.new(client: client_for([movie]))
    assert_equal({ type: "movie", id: 123 }, resolver.call(record))
  end

  test "a homonym or a different chronology is never enough" do
    [movie(summary: "Une famille part en vacances au soleil"), movie(year: 1950)].each do |candidate|
      resolver = RecordPosters::FilmTarget.new(client: client_for([candidate]))
      assert_nil resolver.call(record)
    end
  end

  test "multiple supported identities and incomplete searches remain unresolved" do
    resolver = RecordPosters::FilmTarget.new(client: client_for([movie, movie(id: 124)]))
    assert_nil resolver.call(record)
    resolver = RecordPosters::FilmTarget.new(client: client_for([movie], pages: 21))
    assert_nil resolver.call(record)
  end

  test "previous contradictory identities cannot be bypassed through another search" do
    item = record(evidence: { "tmdb_movie_id" => 123, "url" => "https://www.themoviedb.org/movie/124" })
    resolver = RecordPosters::FilmTarget.new(client: Object.new)
    assert_not RecordPosters::FilmTarget.searchable?(item)
    assert_nil resolver.call(item)
  end
end
