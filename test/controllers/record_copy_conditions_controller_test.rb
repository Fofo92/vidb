require 'test_helper'

class RecordCopyConditionsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'copy-condition@example.com', password: 'password')
    sign_in @user
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @record = Record.create!(french_title: 'Film', record_kind: 'standalone_video', language_version: language)
    @asset = @record.video_assets.create!(last_known_path: '/videos/Film (d).mkv')
  end

  def values
    { fingerprint: VideoAssets::ConditionUpdate.fingerprint(@asset.reload), integrality: 'incomplete',
      damage: 'light', retained_portion: 'beginning', retained_duration_minutes: '41', note: '' }
  end

  test 'edit shows independent qualification and authenticated update preserves the copy' do
    get edit_record_copy_condition_url(@record, @asset)
    assert_response :success
    assert_select 'select[name="copy_condition[integrality]"]'
    path = @asset.last_known_path
    patch record_copy_condition_url(@record, @asset), params: { copy_condition: values }
    assert_redirected_to record_url(@record)
    assert_equal 2460, @asset.reload.condition_details['retained_duration_seconds']
    assert_equal path, @asset.last_known_path
    get record_url(@record)
    assert_response :success
    assert_select '[data-copy-condition]', text: /Durée conservée : 41 min/
  end

  test 'copy cannot be qualified through another record' do
    other = Record.create!(french_title: 'Autre', record_kind: 'standalone_video', language_version: @record.language_version)
    patch record_copy_condition_url(other, @asset), params: { copy_condition: values }
    assert_response :not_found
  end

  test 'stale form returns conflict and invalid duration returns validation errors' do
    stale = values
    @asset.update!(duration_minutes: 52)
    patch record_copy_condition_url(@record, @asset), params: { copy_condition: stale }
    assert_response :conflict
    patch record_copy_condition_url(@record, @asset), params: { copy_condition: values.merge(retained_duration_minutes: 'bad') }
    assert_response :unprocessable_content
    patch record_copy_condition_url(@record, @asset), params: { copy_condition: values.merge(integrality: 'complete') }
    assert_response :unprocessable_content
  end

  test 'qualification requires authentication and raw evidence cannot be forged' do
    input = values.merge(condition_details: { damage: 'none' }, evidence: [{ origin: 'fake' }])
    patch record_copy_condition_url(@record, @asset), params: { copy_condition: input }
    assert_equal 'manual', @asset.reload.condition_details['evidence'].last['origin']
    sign_out @user
    patch record_copy_condition_url(@record, @asset), params: { copy_condition: values }
    assert_redirected_to new_user_session_url
  end

  test 'editing an imported duration retains its seconds' do
    @asset.update!(condition_details: { 'integrality' => 'incomplete', 'retained_portion' => 'end',
                                      'retained_duration_seconds' => 2371 })
    get edit_record_copy_condition_url(@record, @asset)
    assert_response :success
    assert_select 'input[name="copy_condition[retained_duration_minutes]"][value="39"]'
    assert_select 'input[name="copy_condition[retained_duration_remainder]"][value="31"]'
    patch record_copy_condition_url(@record, @asset),
          params: { copy_condition: values.merge(retained_duration_minutes: '39', retained_duration_remainder: '31') }
    assert_redirected_to record_url(@record)
    assert_equal 2371, @asset.reload.condition_details['retained_duration_seconds']
  end

end
