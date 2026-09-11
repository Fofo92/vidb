require "test_helper"

class RecordChildQualificationsControllerTest <
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

    series = Record.create!(
      french_title: "L’Amie prodigieuse",
      record_kind: "series",
      language_version: language_version
    )

    @season = series.children.create!(
      french_title: "Saison 1",
      record_kind: "season",
      rank: 1,
      language_version: language_version
    )

    @undetermined_child = @season.children.create!(
      french_title: "Épisode à qualifier",
      record_kind: "undetermined",
      rank: 1,
      language_version: language_version
    )

    @qualified_child = @season.children.create!(
      french_title: "Épisode déjà qualifié",
      record_kind: "episode",
      rank: 2,
      language_version: language_version
    )
  end

  test "displays children involved in bulk qualification" do
    get edit_record_child_qualification_url(@season)

    assert_response :success

    assert_select(
      "[data-child-qualification-parent]",
      text: /Saison 1/
    )

    assert_select(
      "[data-child-qualification-target='episode']",
      text: /Épisode/
    )

    assert_select(
      "[data-qualifiable-child='#{@undetermined_child.id}']",
      text: /Épisode à qualifier/
    )

    assert_select(
      "[data-preserved-child='#{@qualified_child.id}']",
      text: /Épisode déjà qualifié/
    )
  end
end
