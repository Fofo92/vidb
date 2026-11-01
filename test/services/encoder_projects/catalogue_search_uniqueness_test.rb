require 'test_helper'

class EncoderProjects::CatalogueSearchUniquenessTest < ActiveSupport::TestCase
  test 'film search removes repeated identities before limiting results or fetching details' do
    client = Object.new
    client.define_singleton_method(:search) { |title:| { 'results' => [7, 7, 8, 9].map { |id| { 'id' => id } } } }
    catalogue = EncoderProjects::FilmCatalogue.new(wikipedia: Object.new, parser: Object.new, tmdb: client)
    fetched = []
    catalogue.define_singleton_method(:movie) { |id| fetched << id; { 'id' => id } }
    assert_equal [7, 8, 9], catalogue.send(:tmdb_films, 'Film').pluck('id')
    assert_equal [7, 8, 9], fetched
  end

  test 'series search keeps five distinct identities and their optional posters' do
    client = Object.new
    client.define_singleton_method(:search) do |title:|
      { 'results' => [7, 7, 8, 9, 10, 11].map { |id| { 'id' => id, 'name' => title, 'poster_path' => '/series.jpg' } } }
    end
    results = EncoderProjects::SeriesCatalogueSearch.new(client: client).call('Série')
    assert_equal [7, 8, 9, 10, 11], results.pluck('tmdb_id')
    assert_equal '/series.jpg', results.first['poster_path']
  end
end
