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

  private

  def copy(record, minutes)
    VideoAsset.create!(record: record, last_known_path: "/videos/copy-#{SecureRandom.hex(8)}.m4v",
                       duration_minutes: minutes, medium: @medium, language_version: @language)
  end
end
