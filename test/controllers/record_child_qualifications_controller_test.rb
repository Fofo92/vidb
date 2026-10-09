require "test_helper"

class RecordChildQualificationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "qualification@example.com", password: "password")
    @language = LanguageVersion.create!(short_name: "VF", long_name: "Français")
    series = Record.create!(french_title: "Série", record_kind: "series", language_version: @language)
    @season = series.children.create!(french_title: "Saison 01", rank: 1, record_kind: "season",
                                     language_version: @language)
    @child = @season.children.create!(french_title: "À qualifier", rank: 1, language_version: @language)
    @qualified = @season.children.create!(french_title: "Déjà qualifié", rank: 2, record_kind: "episode",
                                         language_version: @language)
  end

  test "shows all children and explicit common and individual fields" do
    get edit_record_child_qualification_url(@season)
    assert_response :success
    assert_select "[data-qualifiable-child='#{@child.id}']"
    assert_select "[data-qualifiable-child='#{@qualified.id}']"
    assert_select "input[name='record_child_qualification[child_ids][]'][value='#{@child.id}'][checked]"
    assert_select "input[name='record_child_qualification[child_ids][]'][value='#{@qualified.id}']:not([checked])"
    assert_select "input[name='record_child_qualification[common][fields][]'][value='year']"
    assert_select "select[name='record_child_qualification[common][copy_language_version_id]'][disabled]"
    assert_select "input[name='record_child_qualification[rows][#{@child.id}][fields][]'][value='country_ids']"
    assert_select "input[name='record_child_qualification[parent_snapshot]']"
  end

  test "updates already qualified children through the multi field form" do
    patch record_child_qualification_url(@season), params: metadata(
      @qualified, fields: %w[year is_seen], year: "2019", year_basis: "production", is_seen: "no"
    )
    assert_redirected_to record_url(@season)
    assert_equal 2019, @qualified.reload.year
    assert_equal false, @qualified.effective_state(:is_seen)
    assert_nil @child.reload.year
  end

  test "preserves submitted fields and selection after a validation error" do
    patch record_child_qualification_url(@season), params: metadata(
      @qualified, fields: ["year"], year: "1800", year_basis: "production"
    )
    assert_response :unprocessable_content
    assert_select "[data-child-qualification-errors]"
    assert_select "input[name='record_child_qualification[common][year]'][value='1800']"
    assert_select "input[name='record_child_qualification[child_ids][]'][value='#{@qualified.id}'][checked]"
    assert_select "input[name='record_child_qualification[child_ids][]'][value='#{@child.id}']:not([checked])"
  end

  test "legacy placement submissions still work" do
    patch record_child_qualification_url(@season), params: {
      record_child_qualification: { child_ids: [@child.id], record_kind: "episode" }
    }
    assert_redirected_to record_url(@season)
    assert_equal "episode", @child.reload.record_kind
  end

  test "metadata form remains available when parent offers no compatible nature" do
    @season.update!(record_kind: "standalone_video")
    get edit_record_child_qualification_url(@season)
    assert_response :success
    assert_select "form[action='#{record_child_qualification_path(@season)}']"
    assert_select "input[name='record_child_qualification[common][fields][]'][value='gender_ids']"
  end

  test "rejects a forged snapshot without writing" do
    submitted = metadata(@child, fields: ["year"], year: "2019")
    submitted[:record_child_qualification][:parent_snapshot] = "forged"
    patch record_child_qualification_url(@season), params: submitted
    assert_response :unprocessable_content
    assert_nil @child.reload.year
  end

  test "handles row only changes with an empty common selection" do
    submitted = metadata(@qualified, fields: [])
    submitted[:record_child_qualification][:rows] = {
      @qualified.id.to_s => { fields: ["year"], year: "2020", year_basis: "first_release" }
    }
    patch record_child_qualification_url(@season), params: submitted
    assert_redirected_to record_url(@season)
    assert_equal 2020, @qualified.reload.year
  end

  private

  def metadata(child, **common)
    {
      record_child_qualification: {
        child_ids: [child.id], common: common,
        snapshots: { child.id.to_s => RecordChildQualificationSnapshot.token(child) },
        parent_snapshot: RecordChildQualificationSnapshot.token(@season)
      }
    }
  end
end

