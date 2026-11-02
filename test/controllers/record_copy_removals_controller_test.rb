# frozen_string_literal: true

require 'test_helper'

class RecordCopyRemovalsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'copy-removal@example.com', password: 'password')
    sign_in @user
    language = LanguageVersion.create!(short_name: 'REM', long_name: 'Version test')
    @record = Record.create!(french_title: 'Deux copies', record_kind: 'standalone_video', language_version: language)
    @old = VideoAsset.create!(record: @record, last_known_path: '/videos/old.m4v', duration_minutes: 17,
                              technical_details: { 'preserved_evidence' => 'original' })
    @new = VideoAsset.create!(record: @record, last_known_path: '/videos/new.mkv', duration_minutes: 28)
    @requests = []
    @fail = false
    owner = self
    @bridge = Object.new
    @bridge.define_singleton_method(:call) { |request| owner.send(:bridge_call, request) }
  end

  test 'the trash button targets each present copy independently' do
    get record_url(@record)
    assert_select "[data-video-asset='#{@old.id}'] a[href='#{new_record_copy_removal_path(@record, video_asset_id: @old.id)}']"
    @old.update!(status: 'deleted')
    get record_url(@record)
    assert_select "[data-video-asset='#{@old.id}'] a.btn-outline-danger", count: 0
    assert_select "[data-video-asset='#{@new.id}'] a.btn-outline-danger", count: 1
  end

  test 'confirmation reads only and identifies the exact file and duration' do
    with_bridge { confirmation }
    assert_response :success
    assert_select '[data-copy-removal-confirmation]', text: /17 mn/
    assert_select 'code', text: '/videos/old.m4v'
    assert_equal ['preview'], @requests.map { |request| request['operation'] }
    assert @old.reload.status_present?
  end

  test 'confirmed removal retains history and excludes only the selected copy from measured durations' do
    with_bridge { submit(confirmation) }
    assert_response :see_other
    assert_redirected_to record_path(@record)
    assert @old.reload.status_deleted?
    assert @new.reload.status_present?
    assert_equal 'original', @old.technical_details['preserved_evidence']
    assert_equal @user.id, @old.technical_details.dig('copy_removal', 'user_id')
    assert_not @old.technical_details.key?('copy_removal_pending')
    assert_equal 2, @record.video_assets.count
    get record_url(@record)
    assert_select "[data-copy-duration='#{@record.id}']", text: '28 mn'
  end

  test 'invalid or expired confirmations never call the removal bridge' do
    with_bridge do
      submit('invalid')
      token = confirmation
      travel 31.minutes do
        submit(token)
      end
    end
    assert_equal ['preview'], @requests.map { |request| request['operation'] }
    assert @old.reload.status_present?
  end

  test 'a copy belonging to another record cannot be selected' do
    other = Record.create!(french_title: 'Autre œuvre', record_kind: 'standalone_video',
                           language_version: @record.language_version)
    get new_record_copy_removal_url(other, video_asset_id: @old.id)
    assert_response :not_found
  end

  test 'a path changed after confirmation cannot delete the old or the new file' do
    with_bridge do
      token = confirmation
      @old.update!(last_known_path: '/videos/renamed.m4v')
      submit(token)
    end
    assert_equal ['preview'], @requests.map { |request| request['operation'] }
    assert @old.reload.status_present?
  end

  test 'a failed bridge leaves a resumable plan with the same operation identifier' do
    with_bridge do
      token = confirmation
      @fail = true
      submit(token)
      assert @old.reload.status_present?
      assert @old.technical_details['copy_removal_pending']
      @fail = false
      submit(confirmation)
    end
    assert @old.reload.status_deleted?
    assert_equal %w[preview remove remove], @requests.map { |request| request['operation'] }
    assert_equal @requests[1]['id'], @requests[2]['id']
  end

  test 'a repeated successful POST does not remove another file' do
    with_bridge do
      token = confirmation
      submit(token)
      submit(token)
    end
    assert_equal %w[preview remove], @requests.map { |request| request['operation'] }
    assert @new.reload.status_present?
  end

  test 'authentication is required' do
    sign_out @user
    get new_record_copy_removal_url(@record, video_asset_id: @old.id)
    assert_redirected_to new_user_session_path
  end

  private

  def with_bridge(&block)
    VideoAssets::CopyRemovalBridge.stub(:new, -> { @bridge }, &block)
  end

  def confirmation
    get new_record_copy_removal_url(@record, video_asset_id: @old.id)
    assert_response :success
    Nokogiri::HTML(response.body).at_css('input[name="confirmation"]')['value']
  end

  def submit(token)
    post record_copy_removals_url(@record), params: { video_asset_id: @old.id, confirmation: token }
  end

  def bridge_call(request)
    @requests << request
    raise VideoAssets::CopyRemovalBridge::Error, 'Copie utilisée par une tâche active.' if @fail

    return { 'path' => request['path'], 'identity' => [1, 2, 3, '4', '5'], 'token' => 'test-token' } if
      request['operation'] == 'preview'

    { 'path' => request['path'], 'id' => request['id'], 'directory' => '/videos/.video_encoder_trash/test',
      'archived' => '/videos/.video_encoder_trash/test/0-old.m4v' }
  end
end
