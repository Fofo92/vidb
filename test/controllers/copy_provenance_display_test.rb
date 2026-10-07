# frozen_string_literal: true

require 'test_helper'

class CopyProvenanceDisplayTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'copy-provenance@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'PROV', long_name: 'Version test')
    @record = Record.create!(french_title: 'Provenance test', language_version: language,
                             record_kind: 'standalone_video')
    @asset = VideoAsset.create!(record: @record, last_known_path: '/videos/provenance-test.mkv')
  end

  test 'technical observations alone do not claim manual confirmation' do
    show_details('streams' => [{ 'codec_type' => 'audio', 'codec_name' => 'aac' }])
    assert_select '[data-copy-confirmation]', count: 0
    assert_select '[data-copy-reconciliation]', count: 0
    assert_select '[data-confirmed-video-assets]', text: /audio.*aac/m
  end

  test 'batch reconciliation shows its actual provenance without inventing a confirmer' do
    show_details('reconciliation' => {
                   'source_inventory' => { 'generated_at' => '2026-10-07T00:52:44+02:00' }
                 })
    assert_select '[data-copy-confirmation]', count: 0
    assert_select '[data-copy-reconciliation]', text: /Inventaire du 2026-10-07T00:52:44/
  end

  test 'manual qualification retains its author date and language evidence' do
    show_details('confirmation' => {
                   'confirmed_by' => 'Pascal', 'confirmed_on' => '2026-10-07',
                   'language_basis' => 'Français confirmé par écoute'
                 })
    assert_select '[data-copy-confirmation]', text: /Pascal.*2026-10-07/m
    assert_select '[data-copy-language-basis]', text: 'Français confirmé par écoute'
  end

  test 'incomplete confirmation does not produce a broken sentence' do
    show_details('confirmation' => { 'confirmed_by' => 'Pascal' })
    assert_select '[data-copy-confirmation]', count: 0
  end

  private

  def show_details(details)
    @asset.update!(technical_details: details)
    get record_url(@record)
    assert_response :success
  end
end
