require "test_helper"

class RecordCopySupportsHelperTest < ActionView::TestCase
  helper RecordCopiesHelper, RecordChildQualificationsHelper, RecordsHelper

  setup do
    @vf = LanguageVersion.create!(short_name: "VF", long_name: "Français support qualification")
    @hd = Medium.create!(short_name: "HD", long_name: "Hard Drive qualification")
    @record = Record.create!(french_title: "Support qualification", language_version: @vf)
    @qualification_targets = []
    @genders = @countries = []
    @media = [[@hd.long_name, @hd.id]]
    @languages = [[@vf.long_name, @vf.id]]
  end

  test "copy support is selected while duplicate record support is hidden" do
    VideoAsset.create!(record: @record, medium: @hd, status: "present", last_known_path: "/videos/support-qual.mkv")
    render partial: "record_child_qualifications/fields",
           locals: { prefix: "record_child_qualification[rows][#{@record.id}]", key: "child", child: @record, values: {} }
    assert_select "#child_copy_medium_id option[selected][value='#{@hd.id}']"
    assert_select "#child_medium_ids", count: 0
    assert_empty @record.reload.media
  end

  test "records without copies retain the record support control" do
    @record.media << @hd
    render partial: "record_child_qualifications/fields",
           locals: { prefix: "record_child_qualification[rows][#{@record.id}]", key: "child", child: @record, values: {} }
    assert_select "#child_medium_ids option[selected][value='#{@hd.id}']"
    assert_not record_present_copies?(@record)
    assert_not record_present_copies?(Record.new(language_version: @vf))
  end
end
