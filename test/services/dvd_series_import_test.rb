require "test_helper"

class DvdSeriesImportTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.find_or_create_by!(short_name: "IND") { |item| item.long_name = "Indéterminée" }
    @client = Object.new
    @client.define_singleton_method(:get) do |path, language: "fr-FR"|
      if path == "tv/4018"
        { "id" => 4018, "name" => "Code Quantum", "original_name" => "Quantum Leap",
          "first_air_date" => "1989-03-26", "original_language" => "en", "overview" => "Une série.",
          "seasons" => [{ "season_number" => 1 }], "genres" => [], "origin_country" => ["US"] }
      else
        raise "unexpected endpoint" unless path == "tv/4018/season/1"

        { "id" => 101, "season_number" => 1, "overview" => "Une saison.",
          "episodes" => (1..2).map do |number|
            { "id" => 1000 + number, "episode_number" => number,
              "name" => "#{language} #{number}", "overview" => "Un épisode.",
              "air_date" => "1989-03-26", "runtime" => 45 }
          end }
      end
    end
  end

  test "imports a full neutral catalogue and summaries then records only confirmed DVD contents" do
    edition = DvdSeriesImport.new(client: @client).call(ean: "5050582454376", series_id: 4018)
    root = edition.record
    episodes = root.descendants.where(record_kind: "episode").order(:rank).to_a
    assert_equal 2, episodes.size
    assert_equal "Une série.", root.abstract
    assert_equal "Une saison.", root.children.sole.abstract
    assert_empty edition.dvd_contents
    assert_no_difference("VideoAsset.count") do
      DvdContentSelection.new.call(edition: edition, rows: {
        episodes.first.id.to_s => { "selected" => "1", "language_version_id" => @language.id,
                                    "audio_languages" => "français, anglais", "subtitle_languages" => "français" }
      })
    end
    assert_equal [episodes.first.id], edition.dvd_contents.pluck(:record_id)
    episodes.each do |episode|
      assert_equal false, episode.reload.is_available
      assert_equal false, episode.is_recorded
      assert_equal "IND", episode.language_version.short_name
      assert_equal "Un épisode.", episode.abstract
    end
    assert_equal "français, anglais", edition.dvd_contents.sole.audio_languages
    assert_no_difference(["Record.count", "DvdContent.count", "CatalogueEpisodeLink.count"]) do
      DvdSeriesImport.new(client: @client).call(ean: edition.ean, series_id: 4018)
    end
  end

  test "selection cannot attach an episode from another series and rolls back" do
    edition = DvdSeriesImport.new(client: @client).call(ean: "5050582454376", series_id: 4018)
    other_series = Record.create!(
      french_title: "Autre série", record_kind: "series", language_version: @language
    )
    other_season = other_series.children.create!(
      french_title: "Saison 01", record_kind: "season", rank: 1, language_version: @language
    )
    other = other_season.children.create!(
      french_title: "Autre épisode", record_kind: "episode", rank: 1, language_version: @language
    )
    assert_no_difference("DvdContent.count") do
      assert_raises(ArgumentError) do
        DvdContentSelection.new.call(edition: edition, rows: { other.id.to_s => { "selected" => "1" } })
      end
    end
  end

  test "unchecking removes only the holding in this edition" do
    edition = DvdSeriesImport.new(client: @client).call(ean: "5050582454376", series_id: 4018)
    episode = edition.record.descendants.find_by!(record_kind: "episode")
    other = DvdEdition.create!(ean: "3384442021449", record: edition.record)
    [edition, other].each { |item| item.dvd_contents.create!(record: episode) }
    DvdContentSelection.new.call(edition: edition, rows: {})
    assert_empty edition.dvd_contents.reload
    assert_equal episode.id, other.dvd_contents.sole.record_id
  end

  test "DVD inventory preserves existing viewing and recording states and episode language" do
    edition = DvdSeriesImport.new(client: @client).call(ean: "5050582454376", series_id: 4018)
    episode = edition.record.descendants.find_by!(record_kind: "episode")
    french = LanguageVersion.find_or_create_by!(short_name: "VF") { |item| item.long_name = "Française" }
    episode.update!(is_available: true, is_seen: true, language_version: french, abstract: "Résumé manuel.")
    DvdContentSelection.new.call(edition: edition, rows: {
      episode.id.to_s => { "selected" => "1", "language_version_id" => @language.id }
    })
    DvdSeriesImport.new(client: @client).call(ean: edition.ean, series_id: 4018)
    assert_equal true, episode.reload.is_available
    assert_equal true, episode.is_recorded
    assert_equal true, episode.is_seen
    assert_equal french.id, episode.language_version_id
    assert_equal "Résumé manuel.", episode.abstract
    assert_equal @language.id, edition.dvd_contents.sole.language_version_id
  end
end
