require "test_helper"

class RecordPosters::TargetTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: "IND", long_name: "Indéterminée")
  end

  test "two homonymous series retain separate identities through their own descendants" do
    original = series("Code Quantum", 4018)
    reboot = series("Code Quantum", 202102)
    assert_equal({ type: "tv", id: 4018 }, RecordPosters::Target.call(original))
    assert_equal({ type: "tv", id: 202102 }, RecordPosters::Target.call(reboot))
    assert_equal({ type: "tv", id: 4018, season: 1 }, RecordPosters::Target.call(original.children.first))
  end

  test "a conflicting legacy source prevents automatic artwork selection" do
    record = series("Code Quantum", 202102)
    record.update_columns(year_evidence: { "source" => "https://www.themoviedb.org/tv/4018", "tmdb_id" => 4018 })
    assert_nil RecordPosters::Target.call(record)
  end

  test "scoped legacy film identity is accepted but a bare or television id is not" do
    record = Record.create!(french_title: "Film", record_kind: "standalone_video", language_version: @language)
    record.update_columns(year_evidence: { "tmdb_id" => 123 })
    assert_nil RecordPosters::Target.call(record)
    record.update_columns(year_evidence: { "source" => "https://www.themoviedb.org/tv/123" })
    assert_nil RecordPosters::Target.call(record)
    record.update_columns(year_evidence: { "source" => "https://www.themoviedb.org/movie/123" })
    assert_equal({ type: "movie", id: 123 }, RecordPosters::Target.call(record))
  end

  test "does not assume local season rank is the external season number" do
    record = series("Série", 4018)
    season = record.children.first
    season.update_columns(rank: 9)
    assert_equal 1, RecordPosters::Target.call(season).fetch(:season)
  end

  private

  def series(title, tmdb_id)
    record = Record.create!(french_title: title, record_kind: "series", language_version: @language)
    season = record.children.create!(french_title: "Saison 01", rank: 1, record_kind: "season", language_version: @language)
    episode = season.children.create!(french_title: "Épisode", rank: 1, record_kind: "episode", language_version: @language)
    CatalogueEpisodeLink.create!(record: episode, provider: "tmdb", external_series_id: tmdb_id,
                                external_episode_id: tmdb_id, local_season_number: 1, local_episode_number: 1,
                                external_season_number: 1, external_episode_number: 1)
    record
  end
end
