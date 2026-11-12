require 'test_helper'

class RecordPosters::SeriesTargetTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @series = Record.create!(french_title: 'Série pilote', original_title: 'Pilot Series',
                             record_kind: 'series', language_version: @language)
    @season = @series.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season', language_version: @language)
    %w[Premier Deuxième].zip(%w[First Second]).each_with_index do |(french, original), index|
      @season.children.create!(french_title: french, original_title: original, rank: index + 1, year: 2020,
                               record_kind: 'episode', language_version: @language)
    end
    @results = [{ 'id' => 700, 'name' => 'Série pilote', 'original_name' => 'Pilot Series' }]
    @remote = [{ 'id' => 701, 'episode_number' => 1, 'name' => 'Premier', 'air_date' => '2020-01-01' },
               { 'id' => 702, 'episode_number' => 2, 'name' => 'Deuxième', 'air_date' => '2020-01-08' }]
    @original = @remote.each_with_index.map { |episode, index| episode.merge('name' => %w[First Second][index]) }
    @pages = 1
    @calls = []
    @search_calls = []
    @search_pages = nil
  end

  test 'a preexisting series is identified by bilingual episodes numbers and years without writes' do
    before = @series.subtree.order(:id).map(&:attributes)
    assert_equal({ type: 'tv', id: 700 }, resolver.call(@series))
    assert_equal before, @series.subtree.order(:id).map(&:attributes)
    assert_equal 0, CatalogueEpisodeLink.count
  end

  test 'two corroborated homonyms remain unresolved' do
    @results << @results.first.merge('id' => 800)
    assert_nil resolver.call(@series)
  end

  test 'incomplete search results never select the first candidate' do
    @pages = 2
    assert_nil resolver.call(@series)
    assert_empty @calls
  end

  test 'title numbering chronology and original title contradictions block recovery' do
    @remote.first['air_date'] = '2019-01-01'
    assert_nil resolver.call(@series)
    @remote.first['air_date'] = '2020-01-01'
    @remote.first['episode_number'] = 2
    assert_nil resolver.call(@series)
    @remote.first['episode_number'] = 1
    @original.first['name'] = 'Unrelated Story'
    assert_nil resolver.call(@series)
  end

  test 'generic titles and a single known episode cannot identify a series' do
    @season.children.first.update!(french_title: 'Épisode 1')
    assert_nil resolver.call(@series)
    @season.children.last.destroy!
    @calls.clear
    assert_nil resolver.call(@series)
    assert_empty @calls
  end

  test 'previous conflicting identities cannot be bypassed by a new title search' do
    @series.update_columns(year_evidence: { 'tmdb_series_id' => 700, 'source' => 'https://www.themoviedb.org/tv/800' })
    assert_not RecordPosters::SeriesTarget.searchable?(@series)
    assert_nil resolver.call(@series)
    assert_empty @calls
  end

  test 'a mismatched translated episode id cannot corroborate the original title' do
    @original.first['id'] = 999
    assert_nil resolver.call(@series)
  end

  test 'invalid reference dates and invalid historical years cannot corroborate a series' do
    @remote.first['air_date'] = @original.first['air_date'] = '2020-99-99'
    assert_nil resolver.call(@series)
    @remote.first['air_date'] = @original.first['air_date'] = nil
    @season.children.first.update_column(:year, 0)
    assert_nil resolver.call(@series)
  end

  test 'all known seasons are checked rather than a cherry picked episode' do
    other = @series.children.create!(french_title: 'Saison 02', rank: 2, record_kind: 'season', language_version: @language)
    other.children.create!(french_title: 'Autre aventure', rank: 1, year: 2021, record_kind: 'episode', language_version: @language)
    assert_nil resolver.call(@series)
  end

  test 'a candidate on a later search page can be corroborated by episodes' do
    @pages = 2
    unrelated = 20.times.map { |n| { 'id' => n + 100, 'name' => "Autre série #{n}" } }
    @search_pages = { 1 => unrelated, 2 => @results }
    assert_equal({ type: 'tv', id: 700 }, resolver.call(@series))
    assert_equal [1, 2], @search_calls
  end

  test 'a supported homonym on a later page prevents automatic selection' do
    @pages = 2
    @search_pages = { 1 => @results, 2 => [@results.first.merge('id' => 800)] }
    assert_nil resolver.call(@series)
    assert_equal [1, 2], @search_calls
  end

  private

  def resolver
    client = Object.new
    client.define_singleton_method(:search) do |title:, page: 1|
      @test_search_calls << page
      rows = @test_search_pages ? @test_search_pages.fetch(page) : @test_results
      total = @test_search_pages ? @test_search_pages.values.sum(&:size) : @test_results.size
      { 'results' => rows, 'page' => page, 'total_pages' => @test_pages, 'total_results' => total }
    end
    client.instance_variable_set(:@test_results, @results)
    client.instance_variable_set(:@test_pages, @pages)
    client.instance_variable_set(:@test_search_pages, @search_pages)
    client.instance_variable_set(:@test_search_calls, @search_calls)
    calls, french, original = @calls, @remote, @original
    client.define_singleton_method(:get) do |path, language: 'fr-FR'|
      calls << [path, language]
      id = path.split('/')[1].to_i
      if path.match?(%r{\Atv/\d+\z})
        { 'id' => id, 'original_language' => 'en' }
      else
        { 'season_number' => 1, 'episodes' => language == 'en' ? original : french }
      end
    end
    RecordPosters::SeriesTarget.new(client: client)
  end
end
