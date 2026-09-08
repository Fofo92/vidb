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

  test "counts episode states for a season" do
    series = create_record(
      "Série",
      seen: false,
      available: false
    )
    season = create_child(series, "Saison 1")

    episode_one = create_child(season, "Épisode 1")
    episode_one.update!(
      is_recorded: true,
      is_seen: true,
      is_available: false
    )

    episode_two = create_child(season, "Épisode 2")
    episode_two.update!(
      is_recorded: true,
      is_seen: false,
      is_available: true
    )

    create_child(season, "Épisode 3")

    assert_equal 2, season.number_of_recorded_children
    assert_equal 1, season.number_of_seen_children
    assert_equal 1, season.number_of_available_children
  end

  test "requires at least one title" do
    record = build_record(french_title: nil)

    assert_not record.valid?
    assert record.errors[:french_title].any?
    assert record.errors[:original_title].any?

    record.original_title = "Original title"

    assert record.valid?

    record.french_title = "Titre français"
    record.original_title = nil

    assert record.valid?
  end

  test "requires a language version" do
    record = build_record(language_version: nil)

    assert_not record.valid?
    assert record.errors[:language_version].any?
  end

  test "accepts years from 1900 through the current year" do
    [1900, Date.current.year].each do |year|
      assert build_record(year: year).valid?
    end

    [1899, Date.current.year + 1].each do |year|
      assert_not build_record(year: year).valid?
    end
  end

  test "accepts only lengths between 10 and 240 minutes" do
    [nil, 10, 240].each do |length_in_mn|
      assert build_record(length_in_mn: length_in_mn).valid?
    end

    [9, 241].each do |length_in_mn|
      assert_not build_record(length_in_mn: length_in_mn).valid?
    end
  end

  test "allows a parent to contain both branches and leaves" do
    series = create_record(
      "Shaun le mouton",
      seen: false,
      available: false
    )

    season = create_child(
      series,
      "Saison 1",
      rank: 1
    )
    episode = create_child(
      season,
      "Épisode 1",
      rank: 1
    )
    film = create_child(
      series,
      "Shaun le mouton, le film",
      rank: 8
    )

    assert_equal [season, film], series.children.order(:rank).to_a
    assert_equal [series, season], episode.ancestors
    assert_equal [series], film.ancestors

    assert season.has_children?
    assert_not film.has_children?
  end

  test "defaults its kind to undetermined" do
    record = build_record

    assert_equal "undetermined", record.record_kind
    assert record.record_kind_undetermined?
  end

  test "accepts the supported record kinds" do
    supported_kinds = %w[
      undetermined
      standalone_video
      series
      season
      episode
    ]

    supported_kinds.each do |record_kind|
      record = build_record(record_kind: record_kind)

      assert record.valid?
      assert record.public_send("record_kind_#{record_kind}?")
      record.save!

      assert_equal record_kind, record.reload.record_kind
    end
  end

  test "rejects unsupported record kinds" do
    [nil, "", "collection", "unknown"].each do |record_kind|
      record = build_record(record_kind: record_kind)

      assert_not record.valid?
      assert record.errors[:record_kind].any?
    end
  end

  test "database rejects unsupported record kinds" do
    record = create_record(
      "Fiche protégée",
      seen: false,
      available: false
    )

    assert_raises(ActiveRecord::StatementInvalid) do
      Record.transaction(requires_new: true) do
        record.update_column(:record_kind, "collection")
      end
    end

    assert_equal "undetermined", record.reload.record_kind
  end

  test "changing its kind preserves hierarchy rank and states" do
    parent = create_record(
      "Série",
      seen: false,
      available: false
    )
    child = create_child(
      parent,
      "Épisode",
      rank: 7
    )
    child.update!(
      is_recorded: true,
      is_seen: true,
      is_available: false,
      is_checked: true
    )

    preserved_attributes = child.attributes.slice(
      "ancestry",
      "rank",
      "is_recorded",
      "is_seen",
      "is_available",
      "is_checked"
    )

    child.update!(record_kind: "episode")

    assert_equal(
      preserved_attributes,
      child.reload.attributes.slice(*preserved_attributes.keys)
    )
    assert_equal parent, child.parent
  end

test "diagnoses the placement of root records" do
  expected_statuses = {
    "undetermined" => :undetermined,
    "standalone_video" => :consistent,
    "series" => :consistent,
    "season" => :inconsistent,
    "episode" => :inconsistent
  }

  expected_statuses.each do |kind, expected_status|
    record = build_record(record_kind: kind)

    assert_equal(
      expected_status,
      record.hierarchy_placement_status,
      "Unexpected placement status for root #{kind}"
    )
  end
end

test "diagnoses placement from the immediate parent kind" do
  kinds = %w[undetermined standalone_video series season episode]

  expected_statuses = {
    "undetermined" => [
      :undetermined, :undetermined, :inconsistent,
      :undetermined, :undetermined
    ],
    "standalone_video" => [
      :inconsistent, :inconsistent, :inconsistent,
      :inconsistent, :inconsistent
    ],
    "series" => [
      :undetermined, :inconsistent, :inconsistent,
      :consistent, :consistent
    ],
    "season" => [
      :undetermined, :inconsistent, :inconsistent,
      :inconsistent, :consistent
    ],
    "episode" => [
      :inconsistent, :inconsistent, :inconsistent,
      :inconsistent, :inconsistent
    ]
  }

  expected_statuses.each do |parent_kind, statuses|
    parent = build_record(record_kind: parent_kind)
    parent.save!

    kinds.zip(statuses).each do |child_kind, expected_status|
      child = build_record(
        record_kind: child_kind,
        parent: parent
      )

      assert_equal(
        expected_status,
        child.hierarchy_placement_status,
        "Unexpected placement status for #{parent_kind} -> #{child_kind}"
      )
    end
  end
end

  private

  def build_record(attributes = {})
    Record.new(
      {
        french_title: "Titre",
        language_version: @language_version
      }.merge(attributes)
    )
  end

  def create_record(title, seen:, available:)
    Record.create!(
      french_title: title,
      language_version: @language_version,
      is_seen: seen,
      is_available: available
    )
  end

  def create_child(parent, title, year: nil, length_in_mn: nil, rank: nil)
    parent.children.create!(
      french_title: title,
      year: year,
      length_in_mn: length_in_mn,
      rank: rank,
      language_version: @language_version
    )
  end
end
