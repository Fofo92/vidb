require "test_helper"

class RecordCopySupportsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "copy-supports@example.com", password: "password")
    vf = LanguageVersion.create!(short_name: "VF", long_name: "Français support formulaire")
    @hd = Medium.create!(short_name: "HD", long_name: "Hard Drive formulaire")
    @series = Record.create!(french_title: "Série support", record_kind: "series", language_version: vf)
    @episode = Record.create!(french_title: "Épisode support", record_kind: "episode", parent: @series,
                              language_version: vf)
    VideoAsset.create!(record: @episode, status: "present", medium: @hd,
                       last_known_path: "/videos/support-formulaire.m4v")
  end

  test "edit shows support from copies without requiring a second association" do
    get edit_record_url(@episode)
    assert_response :success
    assert_select "[data-record-copy-supports]", text: /HD/
    assert_select "input[name='record[medium_ids][]']", count: 0
    assert_empty @episode.reload.media
  end

  test "child qualification shows the actual copy support and omits the duplicate field" do
    get edit_record_child_qualification_url(@series)
    assert_response :success
    assert_select "[data-qualifiable-child='#{@episode.id}']" do
      assert_select "select[id='child_#{@episode.id}_copy_medium_id'] option[selected][value='#{@hd.id}']"
      assert_select "select[id='child_#{@episode.id}_medium_ids']", count: 0
      assert_select "p", text: /HD/
    end
  end

  test "a record without copies keeps its editable support" do
    other = Record.create!(french_title: "Sans copie", record_kind: "standalone_video",
                            language_version: @episode.language_version, media: [@hd])
    get edit_record_url(other)
    assert_response :success
    assert_select "input[name='record[medium_ids][]'][value='#{@hd.id}'][checked]"
    assert_select "[data-record-copy-supports]", count: 0
  end
end
