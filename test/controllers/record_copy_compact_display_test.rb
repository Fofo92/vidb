# frozen_string_literal: true

require 'test_helper'

class RecordCopyCompactDisplayTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'compact-copies@example.com', password: 'password')
    @vf = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @vm = LanguageVersion.create!(short_name: 'VM', long_name: 'Version multilingue')
    @record = Record.create!(french_title: 'Film versions multiples', record_kind: 'standalone_video', language_version: @vf)
  end

  test 'displays each encoded copy with its own language' do
    first = copy('version-francaise.mkv', @vf)
    second = copy('version-multilingue.mkv', @vm)
    get record_url(@record)
    assert_response :success
    assert_select '[data-confirmed-video-assets] table tbody tr', count: 2
    assert_select "[data-video-asset='#{first.id}'] [data-copy-language]", text: 'VF'
    assert_select "[data-video-asset='#{second.id}'] [data-copy-language]", text: 'VM'
  end

  test 'does not present the catalogue language as a copy confirmation' do
    asset = copy('langue-inconnue.mkv', nil)
    get record_url(@record)
    assert_select "[data-video-asset='#{asset.id}'] [data-copy-language]", text: 'À qualifier'
    assert_select "[data-video-asset='#{asset.id}'] [data-copy-language]", text: /VF/, count: 0
  end

  test 'keeps full paths and provenance inside a collapsed disclosure' do
    asset = copy('film.mkv', @vf)
    asset.update!(technical_details: { 'language_qualification' => {
                    'language_version' => 'VF', 'decided_by' => 'Pascal', 'decided_on' => '2026-10-16',
                    'reason' => 'Pistes vérifiées'
                  } })
    get record_url(@record)
    assert_select "[data-video-asset='#{asset.id}'] details:not([open])" do
      assert_select 'summary', text: 'film.mkv'
      assert_select '[data-copy-path]', text: asset.last_known_path
      assert_select '[data-copy-language-qualification]', text: /VF.*Pascal.*Pistes vérifiées/m
    end
    assert_select "[data-video-asset='#{asset.id}'] summary", text: /\/videos\//, count: 0
  end

  test 'retains deleted copy status and broadcast part numbering' do
    @record.update!(broadcast_part_count: 2)
    asset = VideoAsset.create!(record: @record, last_known_path: '/videos/partie-1.mkv',
                               language_version: @vf, broadcast_part_number: 1, status: 'deleted')
    get record_url(@record)
    assert_select "[data-video-asset='#{asset.id}']", text: /Supprimée.*Partie 1\/2/m
  end

  private

  def copy(filename, language)
    VideoAsset.create!(record: @record, last_known_path: "/videos/Films/#{filename}",
                       duration_minutes: 113, language_version: language)
  end
end
