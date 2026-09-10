require "test_helper"

class RecordHierarchyPlacementsControllerTest <
    ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "test@example.com",
      password: "password"
    )
    sign_in user

    language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    @series = Record.create!(
      french_title: "Série source",
      record_kind: "series",
      language_version: language_version
    )

    @season = @series.children.create!(
      french_title: "Saison 1",
      record_kind: "season",
      rank: 1,
      language_version: language_version
    )

    @season.children.create!(
      french_title: "Épisode 1",
      record_kind: "episode",
      rank: 1,
      language_version: language_version
    )
  end

  test "displays the current hierarchy placement" do
    get edit_record_hierarchy_placement_url(@season)

    assert_response :success
    assert_select "[data-hierarchy-record]", text: /Saison 1/
    assert_select(
      "[data-hierarchy-current-parent]",
      text: /Série source/
    )
    assert_select(
      "[data-hierarchy-descendant-count]",
      text: /1/
    )
  end

  test "moves a hierarchy branch to a compatible parent" do
    destination_series = Record.create!(
      french_title: "Série destinataire",
      record_kind: "series",
      language_version: @series.language_version
    )
    episode = @season.children.first

    patch record_hierarchy_placement_url(@season), params: {
      hierarchy_placement: {
        parent_id: destination_series.id
      }
    }

    assert_redirected_to record_url(@season)

    assert_equal destination_series, @season.reload.parent
    assert_equal 1, @season.rank

    assert_equal @season, episode.reload.parent
    assert_equal 1, episode.rank
  end

   test "rejects moving a branch under an incompatible parent" do
    incompatible_parent = Record.create!(
      french_title: "Vidéo autonome",
      record_kind: "standalone_video",
      language_version: @series.language_version
    )

    patch record_hierarchy_placement_url(@season), params: {
      hierarchy_placement: {
        parent_id: incompatible_parent.id
      }
    }

    assert_response :unprocessable_content
    assert_equal @series, @season.reload.parent
    assert_select(
      "[data-hierarchy-errors]",
      text: /ne permet pas ce placement/
    )
    assert_select(
      "[data-hierarchy-current-parent]",
      text: /Série source/
    )
    assert_select(
      "[data-hierarchy-current-parent] a",
      text: "Vidéo autonome",
      count: 0
    )
  end

  test "moves a root-compatible record to the root" do
    record = @series.children.create!(
      french_title: "Vidéo historiquement mal placée",
      record_kind: "undetermined",
      rank: 7,
      language_version: @series.language_version
    )
    record.update!(record_kind: "standalone_video")

    patch record_hierarchy_placement_url(record), params: {
      hierarchy_placement: {
        parent_id: ""
      }
    }

    assert_redirected_to record_url(record)

    record.reload

    assert record.root?
    assert_equal 7, record.rank
  end

  test "rejects moving a season to the root" do
    patch record_hierarchy_placement_url(@season), params: {
      hierarchy_placement: {
        parent_id: ""
      }
    }

    assert_response :unprocessable_content
    assert_equal @series, @season.reload.parent
    assert_select(
      "[data-hierarchy-errors]",
      text: /ne permet pas ce placement/
    )
  end

  test "ignores record attributes outside the move operation" do
    destination_series = Record.create!(
      french_title: "Série destination",
      record_kind: "series",
      language_version: @series.language_version
    )

    original_title = @season.french_title
    original_kind = @season.record_kind
    original_rank = @season.rank

    patch record_hierarchy_placement_url(@season), params: {
      hierarchy_placement: {
        parent_id: destination_series.id,
        french_title: "Titre détourné",
        record_kind: "episode",
        rank: 99
      }
    }

    assert_redirected_to record_url(@season)

    @season.reload

    assert_equal destination_series, @season.parent
    assert_equal original_title, @season.french_title
    assert_equal original_kind, @season.record_kind
    assert_equal original_rank, @season.rank
  end

  test "rejects an unknown parent without moving the record" do
    original_parent = @season.parent

    patch record_hierarchy_placement_url(@season), params: {
      hierarchy_placement: {
        parent_id: -1
      }
    }

    assert_response :not_found
    assert_equal original_parent, @season.reload.parent
  end

  test "rejects moving a branch under one of its descendants" do
    episode = @season.children.first

    original_ancestries = {
      @series.id => @series.ancestry,
      @season.id => @season.ancestry,
      episode.id => episode.ancestry
    }

    patch record_hierarchy_placement_url(@series), params: {
      hierarchy_placement: {
        parent_id: @season.id
      }
    }

    assert_response :unprocessable_content
    assert_select "[data-hierarchy-errors]"

    assert_equal(
      original_ancestries.fetch(@series.id),
      @series.reload.ancestry
    )
    assert_equal(
      original_ancestries.fetch(@season.id),
      @season.reload.ancestry
    )
    assert_equal(
      original_ancestries.fetch(episode.id),
      episode.reload.ancestry
    )

    assert @series.root?
    assert_equal @series, @season.parent
    assert_equal @season, episode.parent
  end

  test "rejects a move request without a parent choice" do
    original_parent = @season.parent

    patch record_hierarchy_placement_url(@season), params: {
      hierarchy_placement: {
        rank: 99
      }
    }

    assert_response :bad_request
    assert_equal original_parent, @season.reload.parent
  end
end
