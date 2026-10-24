require "test_helper"
require "base64"

class RecordPosterTest < ActiveSupport::TestCase
  PNG = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2k0AAAAASUVORK5CYII=").freeze

  setup do
    language = LanguageVersion.create!(short_name: "IND", long_name: "Indéterminée")
    @series = Record.create!(french_title: "Série avec affiche", record_kind: "series", language_version: language)
    @season = @series.children.create!(french_title: "Saison 01", rank: 1, record_kind: "season", language_version: language)
    @episode = @season.children.create!(french_title: "Épisode", rank: 1, record_kind: "episode", language_version: language)
  end

  test "artwork does not change any record attributes or states" do
    before = @episode.attributes
    RecordPosters::Store.call(@episode, bytes: PNG, source: { "kind" => "manual" })
    assert_equal before, @episode.reload.attributes
    assert @episode.record_poster.image.attached?
  end

  test "season and episode fall back to series without inheriting film artwork" do
    RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "manual" })
    assert_equal @series.record_poster, RecordPosters::Display.call(@season)
    assert_equal @series.record_poster, RecordPosters::Display.call(@episode)
    @series.update!(record_kind: "collection")
    assert_nil RecordPosters::Display.call(@episode.reload)
  end

  test "a season own poster takes priority and episodes still use the series poster" do
    RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "manual" })
    RecordPosters::Store.call(@season, bytes: PNG, source: { "kind" => "manual" })
    assert_equal @season.record_poster, RecordPosters::Display.call(@season)
    assert_equal @series.record_poster, RecordPosters::Display.call(@episode)
  end

  test "automatic import preserves a manual poster and a manual suppression" do
    RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "manual" })
    original = @series.record_poster.image.blob_id
    assert_equal :preserved, RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "tmdb" }, automatic: true)
    assert_equal original, @series.record_poster.reload.image.blob_id
    @series.record_poster.image.purge
    assert_equal :preserved, RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "tmdb" }, automatic: true)
    assert_not @series.record_poster.reload.image.attached?
  end

  test "rejects arbitrary text SVG and oversized uploads before creating a poster" do
    ["not an image", '<svg xmlns="http://www.w3.org/2000/svg"></svg>', "x" * (RecordPoster::MAX_BYTES + 1)].each do |bytes|
      assert_raises(RecordPosters::Store::Error) do
        RecordPosters::Store.call(@series, bytes: bytes, source: { "kind" => "manual" })
      end
    end
    assert_not RecordPoster.exists?(record: @series)
  end

  test "automatic fetch downloads once and preserves subsequent imports" do
    @series.update_columns(year_evidence: { "tmdb_series_id" => 4018 })
    client = Object.new
    client.define_singleton_method(:poster) { |_target| { path: "/abc.png", url: "https://www.themoviedb.org/tv/4018" } }
    calls = []
    png = PNG
    download = Object.new
    download.define_singleton_method(:call) { |path| calls << path; png }
    fetcher = RecordPosters::Fetch.new(client: client, download: download)
    before = @series.attributes
    assert_equal :attached, fetcher.call(@series)
    assert_equal :preserved, fetcher.call(@series.reload)
    assert_equal ["/abc.png"], calls
    assert_equal before, @series.reload.attributes
    assert_equal "tmdb", @series.record_poster.source["kind"]
  end

  test "explicit restoration can refill a manually cleared poster" do
    poster = RecordPoster.create!(record: @series, source: { "kind" => "manual" })
    assert_equal :attached, RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "tmdb" },
                                                     automatic: true, restore: true)
    assert poster.reload.image.attached?
    assert_equal :preserved, RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "tmdb" },
                                                      automatic: true, restore: true)
  end

  test "repeated writes replace a cached absence with a persisted poster" do
    assert_nil @series.record_poster
    RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "tmdb" })
    first_id = @series.record_poster.id
    assert_not_nil first_id
    assert @series.record_poster.persisted?
    RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "manual" })
    assert_equal first_id, @series.record_poster.id
    assert_equal "manual", @series.record_poster.reload.source["kind"]
    assert_equal 1, RecordPoster.where(record_id: @series.id).count
  end

  test "a new manual image replaces the old attachment without creating another owner" do
    RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "tmdb" })
    assert_no_difference("RecordPoster.count") do
      RecordPosters::Store.call(@series, bytes: PNG, source: { "kind" => "manual" })
    end
    assert_equal "manual", @series.record_poster.reload.source["kind"]
  end

  test "fetch without identity has no network call and no database change" do
    assert_no_difference("RecordPoster.count") do
      assert_raises(RecordPosters::Fetch::Error) do
        RecordPosters::Fetch.new(client: Object.new, download: Object.new).call(@series)
      end
    end
  end
end
