# frozen_string_literal: true

require 'test_helper'

class RecordDurationControlsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'duration-controls@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'DUR', long_name: 'Version durée')
    @record = Record.create!(french_title: 'Durée comparée', record_kind: 'standalone_video',
                             length_in_mn: 100, language_version: language)
  end

  test 'concordant measured duration hides catalogue control and preserves its value' do
    copy(105)
    get edit_record_url(@record)
    assert_response :success
    assert_select '#record_reference_duration[readonly][value="01:45"]'
    assert_select 'input[name="record[length_in_mn]"]', count: 0
    assert_equal 100, @record.reload.length_in_mn
  end

  test 'ten percent difference retains the catalogue control' do
    copy(110)
    get edit_record_url(@record)
    assert_select 'details input[name="record[length_in_mn]"][value="100"]'
  end

  test 'an outlying or unmeasured present copy retains the control' do
    copy(105)
    other = copy(120)
    get edit_record_url(@record)
    assert_select 'input[name="record[length_in_mn]"]'
    other.update!(duration_minutes: nil)
    get edit_record_url(@record)
    assert_select 'input[name="record[length_in_mn]"]'
  end

  test 'a deleted copy does not cause a duration discrepancy' do
    copy(105)
    copy(120).update!(status: 'deleted')
    get edit_record_url(@record)
    assert_select 'input[name="record[length_in_mn]"]', count: 0
  end

  test 'no copy or no catalogue value keeps the input accessible' do
    get edit_record_url(@record)
    assert_select 'input[name="record[length_in_mn]"]'
    copy(105)
    @record.update!(length_in_mn: nil)
    get edit_record_url(@record)
    assert_select 'input[name="record[length_in_mn]"]'
  end

  private

  def copy(minutes)
    VideoAsset.create!(record: @record, last_known_path: "/videos/duration-#{SecureRandom.hex(8)}.mkv",
                       duration_minutes: minutes)
  end
end
