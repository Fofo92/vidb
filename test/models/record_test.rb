require "test_helper"

class RecordTest < ActiveSupport::TestCase
  setup do
    @language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    create_record("Vu disponible 1", seen: true, available: true)
    create_record("Vu disponible 2", seen: true, available: true)
    create_record("Vu supprimé", seen: true, available: false)

    create_record("Non vu disponible", seen: false, available: true)
    create_record("Non vu supprimé 1", seen: false, available: false)
    create_record("Non vu supprimé 2", seen: false, available: false)
  end

  test "counts records by viewing and availability status" do
    assert_equal 3, Record.number_of_seen_records
    assert_equal 3, Record.number_of_unseen_records

    assert_equal 2, Record.number_of_seen_and_available_records
    assert_equal 1, Record.number_of_seen_and_removed_records
    assert_equal 1, Record.number_of_unseen_and_available_records
    assert_equal 2, Record.number_of_unseen_and_removed_records
  end

  test "treats nil statuses as false" do
    create_record("Statuts inconnus", seen: nil, available: nil)

    assert_equal 4, Record.number_of_unseen_records
    assert_equal 3, Record.number_of_unseen_and_removed_records
  end

  test "displays its own year when it has no descendants" do
    record = create_record(
      "Film isolé",
      seen: false,
      available: true
    )
    record.update!(year: 1998)

    assert_equal 1998, record.display_range_of_years
  end

  test "displays one year when all descendants have the same year" do
    parent = create_record(
      "Série uniforme",
      seen: false,
      available: true
    )

    create_child(parent, "Épisode 1", year: 2001)
    create_child(parent, "Épisode 2", year: 2001)

    assert_equal "2001", parent.display_range_of_years
  end

  test "displays the descendant year range" do
    parent = create_record(
      "Série étendue",
      seen: false,
      available: true
    )

    create_child(parent, "Premier épisode", year: 2001)
    create_child(parent, "Dernier épisode", year: 2003)

    assert_equal "2001-2003", parent.display_range_of_years
  end

  test "preserves the ancestry chain across three levels" do
    series = create_record(
      "Série",
      seen: false,
      available: true
    )
    season = create_child(series, "Saison 1")
    episode = create_child(season, "Épisode 1")

    assert_equal series, season.parent
    assert_equal season, episode.parent
    assert_equal [series, season], episode.ancestors
    assert_equal(
      "Série / Saison 1 / Épisode 1",
      episode.complete_title_with_parents
    )
  end

  test "uses every descendant to display the year range" do
    series = create_record(
      "Série",
      seen: false,
      available: true
    )
    season = create_child(series, "Saison 1")

    create_child(season, "Premier épisode", year: 2001)
    create_child(season, "Dernier épisode", year: 2003)

    assert_equal "2001-2003", series.display_range_of_years
  end

  test "adds every descendant length to the total" do
    series = create_record(
      "Série",
      seen: false,
      available: true
    )
    season = create_child(series, "Saison 1")

    create_child(season, "Épisode 1", length_in_mn: 45)
    create_child(season, "Épisode 2", length_in_mn: 50)

    assert_equal "01h35", series.formatted_total_length
  end

  test "destroys all descendants when destroying a parent" do
    series = create_record(
      "Série",
      seen: false,
      available: true
    )
    season = create_child(series, "Saison 1")
    episode = create_child(season, "Épisode 1")
    record_ids = [series.id, season.id, episode.id]

    assert_difference("Record.count", -3) do
      series.destroy!
    end

    assert_empty Record.where(id: record_ids)
  end

  private

  def create_record(title, seen:, available:)
    Record.create!(
      french_title: title,
      language_version: @language_version,
      is_seen: seen,
      is_available: available
    )
  end

  def create_child(parent, title, year: nil, length_in_mn: nil)
    parent.children.create!(
      french_title: title,
      year: year,
      length_in_mn: length_in_mn,
      language_version: @language_version
    )
  end
end
