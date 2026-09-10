require "test_helper"

class RecordHierarchyParentSearchTest < ActiveSupport::TestCase
  setup do
    @language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    source_series = create_series("Série source")

    @record = source_series.children.create!(
      french_title: "Saison 1",
      record_kind: "season",
      language_version: @language_version
    )

    @french_title_match = create_series(
      "Les Enquêtes de Vera"
    )

    @original_title_match = create_series(
      "Le Docteur",
      original_title: "Doctor Who"
    )

    create_series("Série sans rapport")
  end

  test "searches French and original titles case-insensitively" do
    assert_equal(
      [@french_title_match],
      search("vera")
    )

    assert_equal(
      [@original_title_match],
      search("DOCTOR")
    )
  end

  test "returns no candidate without a search query" do
    assert_empty search("")
    assert_empty search(nil)
  end

  test "excludes the record, its descendants and its current parent" do
    current_parent = @record.parent
    current_parent.update!(french_title: "Candidat parent actuel")
    @record.update!(french_title: "Candidat déplacé")

    @record.children.create!(
      french_title: "Candidat descendant",
      record_kind: "episode",
      language_version: @language_version
    )

    eligible_parent = create_series("Candidat éligible")

    assert_equal(
      [eligible_parent],
      search("Candidat")
    )
  end

  test "returns only compatible or undetermined parent kinds" do
    undetermined_parent = create_historical_record(
      "Destination indéterminée",
      record_kind: "undetermined"
    )
    series_parent = create_historical_record(
      "Destination série",
      record_kind: "series"
    )

    create_historical_record(
      "Destination vidéo",
      record_kind: "standalone_video"
    )
    create_historical_record(
      "Destination saison",
      record_kind: "season"
    )
    create_historical_record(
      "Destination épisode",
      record_kind: "episode"
    )

    assert_equal(
      [undetermined_parent.id, series_parent.id].sort,
      search("Destination").map(&:id).sort
    )
  end

  private

  def search(query)
    RecordHierarchyParentSearch
      .new(record: @record, query: query)
      .results
      .to_a
  end

  def create_historical_record(french_title, record_kind:)
    record = Record.create!(
      french_title: french_title,
      record_kind: "undetermined",
      language_version: @language_version
    )
    record.update!(record_kind: record_kind)
    record
  end

  def create_series(french_title, original_title: nil)
    Record.create!(
      french_title: french_title,
      original_title: original_title,
      record_kind: "series",
      language_version: @language_version
    )
  end
end
