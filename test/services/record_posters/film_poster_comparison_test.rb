require 'test_helper'

class RecordPosters::FilmPosterComparisonTest < ActiveSupport::TestCase
  LOCAL = 'Tintin Haddock Tournesol Bordurie professeur enlevé enquête château documents aventure danger savants'.freeze
  EXTERNAL = 'Tintin Haddock Tournesol Bordurie diplomatie mystérieuse laboratoire frontière armes recherches voyage secret'.freeze

  def local(title: "L'Affaire Tournesol", year: 1964, original: nil)
    { 'french_title' => title, 'original_title' => original, 'year' => year, 'abstract' => LOCAL }
  end

  def movie(id: 10, title: "L'Affaire Tournesol", year: 1964, original: nil, summary: EXTERNAL)
    { 'id' => id, 'title' => title, 'original_title' => original || title,
      'release_date' => "#{year}-01-01", 'overview' => summary }
  end

  def compare(item = local, movies = [movie])
    RecordPosters::FilmPosterComparison.new.call(local: item, results: movies)
  end

  test 'the exact year resolves the 1964 and 1991 versions despite paraphrased summaries' do
    results = [movie, movie(id: 11, year: 1991, summary: LOCAL)]
    strict = CatalogEnrichment::FilmIdentityComparison.new.call(local: local, results: results)
    assert_equal 'needs_review', strict[:status].to_s
    result = compare(local, results)
    assert_equal 10, result[:tmdb_id]
    assert result[:comparisons].first[:poster_corroborated]
    assert_not result[:comparisons].last[:supported]
  end

  test 'numbers written in words or digits and roman chapter numbers are equivalent for artwork' do
    [["Les douze travaux d'Astérix", "Les 12 travaux d'Astérix"],
     ['Mission Impossible II', 'Mission Impossible 2']].each do |own, external|
      assert_equal 10, compare(local(title: own), [movie(title: external)])[:tmdb_id]
    end
  end

  test 'artwork corroboration does not change the catalogue identity comparison' do
    item = local
    before = Marshal.load(Marshal.dump(item))
    assert_equal 'needs_review', CatalogEnrichment::FilmIdentityComparison.new.call(local: item, results: [movie])[:status].to_s
    assert_equal 'candidate', compare(item)[:status].to_s
    assert_equal before, item
    assert_equal 'needs_review', CatalogEnrichment::FilmIdentityComparison.new.call(local: item, results: [movie])[:status].to_s
  end

  test 'missing year short titles contradictory original titles and distant years do not gain corroboration' do
    cases = [[local(year: nil), movie], [local(year: 1966), movie],
             [local(title: 'Jo'), movie(title: 'Jo')],
             [local(original: 'An unrelated original title'), movie],
             [local, movie(summary: 'Une famille heureuse prend ses vacances à la plage')]]
    cases.each { |item, external| assert_nil compare(item, [external])[:tmdb_id] }
  end

  test 'a distinctive long documentary title allows only one year of chronological variation' do
    title = "Les maîtres du monde : l'Europe face aux géants du numérique"
    assert_equal 10, compare(local(title: title, year: 2023), [movie(title: title, year: 2024)])[:tmdb_id]
    assert_nil compare(local(title: title, year: 2022), [movie(title: title, year: 2024)])[:tmdb_id]
  end

  test 'two corroborated references remain ambiguous' do
    result = compare(local, [movie, movie(id: 11)])
    assert_equal 'needs_review', result[:status].to_s
    assert_nil result[:tmdb_id]
    assert_equal 2, result[:comparisons].count { |row| row[:supported] }
  end

  test 'invalid external dates cannot add contextual evidence' do
    external = movie.merge('release_date' => 'not-a-date')
    assert_nil compare(local, [external])[:tmdb_id]
  end
end
