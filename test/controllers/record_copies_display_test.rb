# frozen_string_literal: true

require 'test_helper'

class RecordCopiesDisplayTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'copies-display@example.com', password: 'password')
    @language = LanguageVersion.create!(short_name: 'COPY', long_name: 'Version test')
    @medium = Medium.create!(short_name: 'DISK', long_name: 'Disque test')
    @root = Record.create!(french_title: 'Série test', language_version: @language, record_kind: 'series')
    @season = @root.children.create!(french_title: 'Saison 01', language_version: @language, record_kind: 'season')
    @episodes = [1, 2].map do |number|
      @season.children.create!(french_title: "Épisode #{number}", language_version: @language,
                               record_kind: 'episode', rank: number)
    end
  end

  test 'season rows and series summary use measured copies' do
    copy(@episodes.first, 52)
    copy(@episodes.last, 54)
    get record_url(@season)
    assert_response :success
    assert_select "[data-copy-duration='#{@episodes.first.id}']", text: '52 mn'
    assert_select "[data-copy-supports='#{@episodes.first.id}']", text: 'DISK'
    assert_select "[data-copy-languages='#{@episodes.first.id}']", text: 'COPY'
    get record_url(@root)
    assert_select "[data-copy-duration='#{@root.id}']", text: '01:46'
    assert_select "[data-copy-duration='#{@season.id}']", text: '01:46'
  end

  test 'multiple copies are not counted twice and deleted copies are excluded' do
    copy(@episodes.first, 52)
    copy(@episodes.first, 53)
    copy(@episodes.last, 54)
    copy(@episodes.last, 120).update!(status: 'deleted')
    get record_url(@season)
    assert_select "[data-copy-duration='#{@season.id}']", text: /01:46–01:47 selon les copies/
  end

  test 'incomplete measured coverage stays explicit' do
    copy(@episodes.first, 52)
    get record_url(@season)
    assert_select "[data-copy-duration='#{@season.id}']", text: /partiel : 1\/2/
    assert_select "[data-copy-supports='#{@season.id}']", text: /couverture 1\/2/
  end

  test 'legacy values are labelled and are not presented as copy confirmations' do
    @episodes.first.update!(length_in_mn: 45)
    get record_url(@season)
    assert_select "[data-copy-duration='#{@episodes.first.id}']", text: /00h45.*catalogue/
    assert_select "[data-copy-languages='#{@episodes.first.id}']", text: /COPY.*catalogue/
    assert_select "[data-copy-supports='#{@episodes.first.id}']", text: 'Non renseigné'
  end

  test 'durations switch to hours at sixty minutes' do
    copy(@episodes.first, 59)
    copy(@episodes.last, 65)
    get record_url(@season)
    assert_select "[data-copy-duration='#{@episodes.first.id}']", text: '59 mn'
    assert_select "[data-copy-duration='#{@episodes.last.id}']", text: '01:05'
    assert_select "[data-copy-duration='#{@season.id}']", text: '02:04'
  end

  test 'edit prioritizes measured duration and retains catalogue as a separate control' do
    episode = @episodes.first
    episode.update!(length_in_mn: 86)
    copy(episode, 88)
    get edit_record_url(episode)
    assert_response :success
    assert_select '#record_reference_duration[readonly][value="01:28"]'
    assert_select '#record_reference_duration[name]', count: 0
    assert_select 'details input[name="record[length_in_mn]"][value="86"]'
    assert_equal 86, episode.reload.length_in_mn
  end

  test 'edit shows copy ranges and excludes deleted copies' do
    episode = @episodes.first
    copy(episode, 88)
    copy(episode, 90)
    copy(episode, 120).update!(status: 'deleted')
    get edit_record_url(episode)
    assert_select '#record_reference_duration[value="01:28–01:30 selon les copies"]'
  end

  test 'season edit calculates a total without offering a container duration input' do
    copy(@episodes.first, 52)
    copy(@episodes.last, 54)
    get edit_record_url(@season)
    assert_response :success
    assert_select '#record_reference_duration[value="01:46"]'
    assert_select 'input[name="record[length_in_mn]"]', count: 0
  end

  test 'edit explicitly shows incomplete measured coverage' do
    copy(@episodes.first, 52)
    get edit_record_url(@season)
    assert_select '#record_reference_duration[value="52 mn — partiel : 1/2"]'
  end

  test 'edit falls back to labelled catalogue when no present copy exists' do
    episode = @episodes.first
    episode.update!(length_in_mn: 86)
    copy(episode, 88).update!(status: 'deleted')
    get edit_record_url(episode)
    assert_select '#record_reference_duration[value="01h26 (catalogue)"]'
    assert_select 'input[name="record[length_in_mn]"][value="86"]'
  end

  test 'new record form does not query a nonexistent copy tree' do
    get new_record_url
    assert_response :success
    assert_select '#record_reference_duration', count: 0
    assert_select 'details[open] input[name="record[length_in_mn]"]'
  end

  private

  def copy(record, minutes)
    VideoAsset.create!(record: record, last_known_path: "/videos/copy-#{SecureRandom.hex(8)}.m4v",
                       duration_minutes: minutes, medium: @medium, language_version: @language)
  end
end
