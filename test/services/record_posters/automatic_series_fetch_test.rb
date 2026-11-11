require 'test_helper'
require 'minitest/mock'

class RecordPosters::AutomaticSeriesFetchTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Version inconnue')
    @series = Record.create!(french_title: 'Ancienne série', record_kind: 'series', language_version: language)
    @season = @series.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season', language_version: language)
    @season.children.create!(french_title: 'Premier', rank: 1, year: 2020, record_kind: 'episode', language_version: language)
    @resolver = ->(_record) { { type: 'tv', id: 700 } }
    @client = Object.new
    @client.define_singleton_method(:poster) { |_target| { path: '/image.jpg', url: 'https://www.themoviedb.org/tv/700' } }
  end

  test 'automatic recovery stores the resolved series identity with the artwork' do
    source = nil
    store = ->(_record, **options) { source = options[:source]; :attached }
    RecordPosters::Store.stub(:call, store) do
      fetcher = RecordPosters::Fetch.new(client: @client, download: ->(_path) { 'image' }, series_target: @resolver)
      assert_equal :attached, fetcher.call(@series)
    end
    assert_equal 'tv', source.dig('target', 'type')
    assert_equal 700, source.dig('target', 'id')
    assert_equal 'https://www.themoviedb.org/tv/700', source['url']
  end

  test 'a catalogue change during the remote request prevents storing a stale identification' do
    download = lambda do |_path|
      @season.children.first.update!(year: 2021)
      'image'
    end
    RecordPosters::Store.stub(:call, ->(*) { flunk 'Do not save stale artwork' }) do
      fetcher = RecordPosters::Fetch.new(client: @client, download: download, series_target: @resolver)
      assert_raises(RecordPosters::Fetch::Error) { fetcher.call(@series) }
    end
  end

  test 'manual artwork policy is preserved without searching or downloading' do
    @series.create_record_poster!(source: { 'kind' => 'manual' })
    fetcher = RecordPosters::Fetch.new(client: @client, download: ->(*) { flunk }, series_target: ->(*) { flunk })
    assert_equal :preserved, fetcher.call(@series.reload)
  end

  test 'a transient remote error can be retried on the next automatic run' do
    calls = 0
    @client.define_singleton_method(:poster) do |_target|
      calls += 1
      raise CatalogEnrichment::TmdbClient::Error, 'temporary failure' if calls == 1

      { path: '/image.jpg', url: 'https://www.themoviedb.org/tv/700' }
    end
    fetcher = RecordPosters::Fetch.new(client: @client, download: ->(*) { 'image' }, series_target: @resolver)
    assert_raises(CatalogEnrichment::TmdbClient::Error) { fetcher.call(@series) }
    RecordPosters::Store.stub(:call, ->(*) { :attached }) do
      assert_equal :attached, fetcher.call(@series)
    end
  end
end
