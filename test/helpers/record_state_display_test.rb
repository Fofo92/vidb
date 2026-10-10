require "test_helper"

class RecordStateDisplayTest < ActionView::TestCase
  helper RecordsHelper, RecordChildQualificationsHelper

  setup do
    language = LanguageVersion.create!(short_name: "VF", long_name: "Français état affiché")
    @record = Record.create!(french_title: "État affiché", record_kind: "standalone_video",
                             language_version: language, is_checked: true, is_seen: false)
  end

  test "table headers have three state columns without verification" do
    render inline: '<table><thead><tr><%= render "records/state_columns", record: record,
                        header: true, interactive: false %></tr></thead></table>', locals: { record: @record }
    assert_select "th[data-state-column]", count: 3
    assert_select "[data-state-column=is_checked]", count: 0
    assert_select "[data-state-column=is_seen]", count: 1
  end

  test "table cells and summary omit verification while preserving legacy seen interpretation" do
    render inline: '<table><tbody><tr><%= render "records/state_columns", record: record,
                        header: false, interactive: false %></tr></tbody></table>', locals: { record: @record }
    assert_select "td[data-state-column]", count: 3
    assert_select "[data-state-column=is_checked]", count: 0
    render partial: "records/state_summary", locals: { record: @record }
    assert_select "[data-state=is_checked]", count: 0
    assert_equal false, @record.reload.effective_state(:is_seen)
    assert_equal true, @record.is_checked
  end

  test "child qualification exposes seen state but no verification field" do
    @qualification_targets = []
    @genders = @countries = @media = @languages = []
    render partial: "record_child_qualifications/fields",
           locals: { prefix: "record_child_qualification[common]", key: "common", child: nil, values: {} }
    assert_select "select[id=common_is_checked]", count: 0
    assert_select "input[value=is_checked]", count: 0
    assert_select "select[id=common_is_seen]", count: 1
  end
end
