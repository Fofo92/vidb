require 'test_helper'
require 'minitest/mock'

class EncoderProjects::EpisodeCatalogueTest < ActiveSupport::TestCase
  Reference = Struct.new(:id)
  Series = Struct.new(:id, :french_title, :original_title, :effective_genders, :effective_countries, :subtree, :year)
  Numbers = Struct.new(:season, :episode)

  class Links
    def initialize(ids)
      @ids = ids
    end

    def where(**_parameters)
      self
    end

    def distinct
      self
    end

    def limit(_number)
      self
    end

    def pluck(_column)
      @ids
    end

    def select(_column)
      self
    end
  end

  def series
    Series.new(123, 'Série test', '', [Reference.new(20)], [Reference.new(13)], Links.new([]))
  end

  def wikipedia(fail: false)
    client = Object.new
    client.define_singleton_method(:search_series) { |_title| raise ArgumentError, 'offline' if fail; ['Série test'] }
    client.define_singleton_method(:page) do |title|
      { 'title' => title, 'text' => { '*' => '<h3>Épisode 1 : Le départ</h3><dl><dt>Première diffusion</dt><dd>2025</dd></dl>' } }
    end
    client
  end

  def tmdb
    client = Object.new
    client.define_singleton_method(:search) { |title:| { 'results' => [] } }
    client.define_singleton_method(:get) do |path|
      if path.include?('/season/')
        { 'episodes' => [{ 'id' => 42, 'episode_number' => 1, 'name' => 'Autre titre', 'air_date' => '2024-12-31' }] }
      else
        { 'genres' => [], 'origin_country' => [] }
      end
    end
    client
  end

  test 'keeps Wikipedia first while exposing differing TMDB proposals' do
    catalogue = EncoderProjects::EpisodeCatalogue.new(wikipedia: wikipedia, tmdb: tmdb, links: Links.new([7]))
    proposals = catalogue.call(series, Numbers.new(2, 1))
    assert_equal %w[wikipedia tmdb], proposals.map { |row| row.dig('source', 'provider') }
    assert_equal [2025, 2024], proposals.map { |row| row['year'] }
    assert_equal [20], proposals.first['gender_ids']
    assert_equal [13], proposals.first['country_ids']
    assert_equal 123, proposals.first['series_id']
    assert_empty catalogue.warnings
  end

  test 'a provider outage preserves the other proposal and gives a warning' do
    catalogue = EncoderProjects::EpisodeCatalogue.new(wikipedia: wikipedia(fail: true), tmdb: tmdb, links: Links.new([7]))
    proposals = catalogue.call(series, Numbers.new(2, 1))
    assert_equal ['tmdb'], proposals.map { |row| row.dig('source', 'provider') }
    assert catalogue.warnings.any?
  end

  test 'no metadata is invented for an absent episode' do
    catalogue = EncoderProjects::EpisodeCatalogue.new(wikipedia: wikipedia, tmdb: tmdb, links: Links.new([]))
    assert_empty catalogue.call(series, Numbers.new(2, 8))
  end
  test 'searches by series identity when a catalogue link is absent' do
    client = tmdb
    client.define_singleton_method(:search) do |title:|
      { 'results' => [{ 'id' => 7, 'name' => title, 'first_air_date' => '2024-01-01' }] }
    end
    catalogue = EncoderProjects::EpisodeCatalogue.new(wikipedia: wikipedia, tmdb: client, links: Links.new([]))
    proposals = catalogue.call(series, Numbers.new(2, 1))
    assert_equal %w[wikipedia tmdb], proposals.map { |row| row.dig('source', 'provider') }
  end

  test 'does not accept a homonymous series from another known year' do
    client = tmdb
    client.define_singleton_method(:search) do |title:|
      { 'results' => [{ 'id' => 7, 'name' => title, 'first_air_date' => '1983-01-01' }] }
    end
    root = series
    root.year = 2024
    catalogue = EncoderProjects::EpisodeCatalogue.new(wikipedia: wikipedia, tmdb: client, links: Links.new([]))
    proposals = catalogue.call(root, Numbers.new(2, 1))
    assert_equal ['wikipedia'], proposals.map { |row| row.dig('source', 'provider') }
  end

end
