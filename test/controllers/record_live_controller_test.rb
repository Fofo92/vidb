require 'test_helper'
require 'minitest/mock'

class RecordLiveControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'live-record@example.com', password: 'password')
    sign_in @user
    language = LanguageVersion.create!(short_name: 'LIVE', long_name: 'Version actualisation')
    series = Record.create!(french_title: 'Série en direct', record_kind: 'series', language_version: language)
    @record = series.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season', language_version: language)
    @episode = @record.children.create!(french_title: 'Ancien épisode', rank: 1, record_kind: 'episode', language_version: language)
  end

  test 'ordinary show advertises the live endpoint and all replaceable regions' do
    get record_url(@record)
    assert_response :success
    assert_select '[data-record-live-root][data-controller="record-states record-live"]', count: 1
    assert_select '[data-record-live-url-value]' do |nodes|
      assert_equal record_live_path(@record), nodes.first['data-record-live-url-value']
      assert_match(/\A[a-f0-9]{64}\z/, nodes.first['data-record-live-version-value'])
    end
    %w[artwork information viewing provenance children].each do |region|
      assert_select "[data-record-live-region='#{region}']", count: 1
    end
  end

  test 'unchanged data returns no content and is not publicly cached' do
    get record_live_url(@record), params: { version: RecordShowVersion.new(@record).call }, as: :json
    assert_response :no_content
    assert_empty response.body
    assert_includes response.headers['Cache-Control'], 'no-store'
  end

  test 'changed children return fresh HTML without a full document or any database mutation' do
    previous = RecordShowVersion.new(@record).call
    @episode.update!(french_title: 'Épisode actualisé')
    before = [@record.reload.attributes, @episode.reload.attributes]
    get record_live_url(@record), params: { version: previous }, as: :json

    assert_response :success
    result = response.parsed_body
    assert_not_equal previous, result.fetch('version')
    assert_includes result.fetch('html'), 'Épisode actualisé'
    assert_not_includes result.fetch('html'), '<html'
    fragment = Nokogiri::HTML.fragment(result.fetch('html'))
    assert_equal 5, fragment.css('[data-record-live-region]').size
    assert_equal before, [@record.reload.attributes, @episode.reload.attributes]
  end

  test 'a child addition and removal refresh the table structure' do
    child = @record.children.create!(french_title: 'Ajouté', rank: 2, record_kind: 'episode',
                                    language_version: @record.language_version)
    get record_live_url(@record), as: :json
    assert_includes response.parsed_body.fetch('html'), "data-record-live-child=\"#{child.id}\""
    previous = response.parsed_body.fetch('version')
    child.destroy!
    get record_live_url(@record), params: { version: previous }, as: :json
    assert_response :success
    assert_not_includes response.parsed_body.fetch('html'), "data-record-live-child=\"#{child.id}\""
  end

  test 'concurrent changes during rendering ask the client to retry' do
    versions = %w[before after]
    reader = Object.new
    reader.define_singleton_method(:call) { versions.shift }
    RecordShowVersion.stub(:new, ->(_record) { reader }) do
      get record_live_url(@record), as: :json
      assert_response :conflict
    end
  end

  test 'live requests require authentication' do
    sign_out @user
    get record_live_url(@record), as: :json
    assert_response :unauthorized
  end

  test 'a missing record returns not found' do
    get record_live_url(record_id: 999_999_999), as: :json
    assert_response :not_found
  end

  test 'the rendered owner is reloaded if it changes before fingerprinting' do
    build = RecordShowVersion.method(:new)
    first = true
    factory = lambda do |record|
      if first
        @record.update_columns(french_title: 'Saison corrigée avant lecture')
        first = false
      end
      build.call(record)
    end
    RecordShowVersion.stub(:new, factory) do
      get record_live_url(@record), as: :json
      assert_response :success
      fragment = Nokogiri::HTML.fragment(response.parsed_body.fetch('html'))
      assert_equal 'Saison corrigée avant lecture', fragment.at_css('[data-record-main-title]').text
    end
  end


  test 'the live controller renders a leaf with its own confirmed copy and nested details' do
    asset = @episode.video_assets.create!(status: 'present', last_known_path: '/videos/live-confirmed.mkv',
                                         duration_minutes: 42,
                                         technical_details: { 'streams' => [{ 'codec_type' => 'video',
                                                                            'codec_name' => 'h264' }] })
    get record_live_url(@episode), as: :json

    assert_response :success
    fragment = Nokogiri::HTML.fragment(response.parsed_body.fetch('html'))
    assert_equal 1, fragment.css("[data-video-asset='#{asset.id}']").size
    assert_equal '/videos/live-confirmed.mkv', fragment.at_css('[data-copy-path]').text
    assert_includes fragment.at_css('[data-confirmed-video-assets]').text, 'h264'
  end

end
