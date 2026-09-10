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
end
