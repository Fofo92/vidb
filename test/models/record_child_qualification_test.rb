require "test_helper"

class RecordChildQualificationTest < ActiveSupport::TestCase
  setup do
    @language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    @series = Record.create!(
      french_title: "Doctor Who",
      record_kind: "series",
      language_version: @language_version
    )
  end

  test "qualifies only selected children of a mixed series" do
    season = create_child("Saison 1", rank: 1)
    special = create_child("Épisode de Noël", rank: 2)

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [season.id],
      record_kind: "season"
    )

    assert operation.call

    assert_equal "season", season.reload.record_kind
    assert_equal "undetermined", special.reload.record_kind

    assert_equal @series.id, season.parent_id
    assert_equal @series.id, special.parent_id
    assert_equal 1, season.rank
    assert_equal 2, special.rank
  end

  test "rejects a target kind incompatible with the parent" do
    child = create_child("Saison à qualifier", rank: 1)

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [child.id],
      record_kind: "series"
    )

    assert_not operation.call
    assert operation.errors[:record_kind].any?
    assert_equal "undetermined", child.reload.record_kind
  end

  test "rejects the whole selection when a record is not a direct child" do
    child = create_child("Saison à qualifier", rank: 1)

    outside_record = Record.create!(
      french_title: "Fiche extérieure",
      record_kind: "undetermined",
      language_version: @language_version
    )

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [child.id, outside_record.id],
      record_kind: "season"
    )

    assert_not operation.call
    assert operation.errors[:child_ids].any?
    assert_equal "undetermined", child.reload.record_kind
    assert_equal "undetermined", outside_record.reload.record_kind
  end

  test "rejects an empty selection" do
    child = create_child("Saison à qualifier", rank: 1)

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [],
      record_kind: "season"
    )

    assert_not operation.call
    assert operation.errors[:child_ids].any?
    assert_equal "undetermined", child.reload.record_kind
  end

  test "rejects the whole selection when a child is already qualified" do
    child = create_child("Saison à qualifier", rank: 1)
    special = create_child("Épisode spécial", rank: 2)
    special.update!(record_kind: "episode")

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [child.id, special.id],
      record_kind: "season"
    )

    assert_not operation.call
    assert operation.errors[:child_ids].any?
    assert_equal "undetermined", child.reload.record_kind
    assert_equal "episode", special.reload.record_kind
  end

  test "rejects the whole operation when qualifying a parent as an episode" do
    leaf = create_child("Épisode spécial", rank: 1)
    branch = create_child("Saison à identifier", rank: 2)

    descendant = branch.children.create!(
      french_title: "Épisode de la saison",
      record_kind: "episode",
      rank: 1,
      language_version: @language_version
    )

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [leaf.id, branch.id],
      record_kind: "episode"
    )

    assert_not operation.call
    assert operation.errors[:child_ids].any?
    assert_equal "undetermined", leaf.reload.record_kind
    assert_equal "undetermined", branch.reload.record_kind
    assert_equal "episode", descendant.reload.record_kind
    assert_equal branch.id, descendant.parent_id
  end

  test "qualifies a season while preserving its children" do
    season = create_child("Saison à identifier", rank: 3)

    episode = season.children.create!(
      french_title: "Épisode identifié",
      record_kind: "episode",
      rank: 1,
      language_version: @language_version
    )

    undetermined = season.children.create!(
      french_title: "Épisode à identifier",
      record_kind: "undetermined",
      rank: 2,
      language_version: @language_version
    )

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [season.id],
      record_kind: "season"
    )

    assert operation.call
    assert_equal "season", season.reload.record_kind
    assert_equal 3, season.rank
    assert_equal "episode", episode.reload.record_kind
    assert_equal "undetermined", undetermined.reload.record_kind
    assert_equal season.id, episode.parent_id
    assert_equal season.id, undetermined.parent_id
    assert_equal 1, episode.rank
    assert_equal 2, undetermined.rank
  end

  test "rolls back all qualifications when a selected record cannot be saved" do
    first_child = create_child("Première saison", rank: 1)
    invalid_child = create_child("Deuxième saison", rank: 2)

    # Represent an invalid record inherited from historical data.
    invalid_child.update_columns(
      french_title: nil,
      original_title: nil
    )

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [first_child.id, invalid_child.id],
      record_kind: "season"
    )

    assert_not operation.call
    assert operation.errors[:base].any?
    assert_equal "undetermined", first_child.reload.record_kind
    assert_equal "undetermined", invalid_child.reload.record_kind
  end

  test "checks the current parent kind before qualifying children" do
    child = create_child("Saison à qualifier", rank: 1)

    operation = RecordChildQualification.new(
      parent: @series,
      child_ids: [child.id],
      record_kind: "season"
    )

    another_parent_instance = Record.find(@series.id)
    another_parent_instance.update!(record_kind: "standalone_video")
    assert_equal "series", @series.record_kind
    assert_equal "standalone_video", Record.find(@series.id).record_kind
    assert_not operation.call
    assert operation.errors[:record_kind].any?
    assert_equal "undetermined", child.reload.record_kind
    assert_equal "standalone_video", @series.reload.record_kind
  end

  private

  def create_child(title, rank:)
    @series.children.create!(
      french_title: title,
      record_kind: "undetermined",
      rank: rank,
      language_version: @language_version
    )
  end
end
