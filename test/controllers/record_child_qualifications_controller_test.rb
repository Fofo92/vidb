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

  test "qualifies selected undetermined children" do
    patch record_child_qualification_url(@season), params: {
      record_child_qualification: {
        child_ids: [@undetermined_child.id],
        record_kind: "episode"
      }
    }

    assert_redirected_to record_url(@season)
    assert_equal "episode", @undetermined_child.reload.record_kind
    assert_equal "episode", @qualified_child.reload.record_kind
  end

  test "redisplays the page when the target kind is incompatible" do
    patch record_child_qualification_url(@season), params: {
      record_child_qualification: {
        child_ids: [@undetermined_child.id],
        record_kind: "season"
      }
    }

    assert_response :unprocessable_content
    assert_equal "undetermined", @undetermined_child.reload.record_kind

    assert_select(
      "[data-child-qualification-errors]",
      text: /n’est pas autorisée/
    )

    assert_select(
      "[data-qualifiable-child='#{@undetermined_child.id}']",
      text: /Épisode à qualifier/
    )
  end

  test "offers an explicit child selection with confirmation" do
    get edit_record_child_qualification_url(@season)

    assert_response :success

    assert_select(
      "form[action='#{record_child_qualification_path(@season)}']"
    ) do
      assert_select "input[name='_method'][value='patch']"

      assert_select(
        "select[name='record_child_qualification[record_kind]'] " \
        "option[value='episode']",
        text: "Épisode"
      )

      assert_select(
        "input[type='checkbox']" \
        "[name='record_child_qualification[child_ids][]']" \
        "[value='#{@undetermined_child.id}'][checked]"
      )

      assert_select(
        "input[type='checkbox']" \
        "[value='#{@qualified_child.id}']",
        count: 0
      )

      assert_select(
        "input[type='submit'][data-turbo-confirm]",
        value: "Qualifier la sélection"
      )
    end
  end

  test "preserves the submitted selection after a rejected qualification" do
    other_child = @season.children.create!(
      french_title: "Autre épisode à qualifier",
      record_kind: "undetermined",
      rank: 3,
      language_version: @season.language_version
    )

    @undetermined_child.children.create!(
      french_title: "Descendant incompatible",
      record_kind: "undetermined",
      language_version: @season.language_version
    )

    patch record_child_qualification_url(@season), params: {
      record_child_qualification: {
        child_ids: [@undetermined_child.id],
        record_kind: "episode"
      }
    }

    assert_response :unprocessable_content

    assert_select(
      "input[type='checkbox']" \
      "[value='#{@undetermined_child.id}'][checked]"
    )

    assert_select(
      "input[type='checkbox'][value='#{other_child.id}']",
      count: 1
    )

    assert_select(
      "input[type='checkbox'][value='#{other_child.id}'][checked]",
      count: 0
    )
  end

  test "preserves the submitted target kind after a rejected qualification" do
    series = @season.parent

    branch = series.children.create!(
      french_title: "Branche à qualifier",
      record_kind: "undetermined",
      rank: 2,
      language_version: series.language_version
    )

    branch.children.create!(
      french_title: "Descendant incompatible",
      record_kind: "undetermined",
      language_version: series.language_version
    )

    patch record_child_qualification_url(series), params: {
      record_child_qualification: {
        child_ids: [branch.id],
        record_kind: "episode"
      }
    }

    assert_response :unprocessable_content

    assert_select(
      "select[name='record_child_qualification[record_kind]'] " \
      "option[value='episode'][selected]"
    )
  end

  test "redisplays the page when no child is selected" do
    patch record_child_qualification_url(@season), params: {
      record_child_qualification: {
        record_kind: "episode"
      }
    }

    assert_response :unprocessable_content
    assert_equal "undetermined", @undetermined_child.reload.record_kind

    assert_select(
      "[data-child-qualification-errors]",
      text: /enfants directs encore à déterminer/
    )
  end

  test "does not offer a form when no target kind is compatible" do
    @season.update!(record_kind: "standalone_video")

    get edit_record_child_qualification_url(@season)

    assert_response :success
    assert_select(
      "form[action='#{record_child_qualification_path(@season)}']",
      count: 0
    )
    assert_select(
      "[data-child-qualification-unavailable]",
      text: /aucune nature compatible/i
    )
  end
end
