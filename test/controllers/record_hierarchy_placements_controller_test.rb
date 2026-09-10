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
end
