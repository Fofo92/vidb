# frozen_string_literal: true

require 'test_helper'

class ConfirmedCopyDetailsTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'COPY', long_name: 'Version confirmée test')
    @medium = Medium.create!(short_name: 'COPY', long_name: 'Support test')
    @record = Record.create!(french_title: 'Copie test', language_version: @language)
    @assets = [1, 2].map do |number|
      VideoAsset.create!(record: @record, last_known_path: "/videos/copy#{number}.m4v", byte_size: 1234)
    end
    @evidence = {
      'format' => 'vidb.confirmed_copy_details', 'version' => 1, 'confirmed_by' => 'Pascal',
      'confirmed_on' => '2026-10-07', 'medium' => 'COPY', 'language_version' => 'COPY',
      'storage_uuid' => 'volume-test', 'language_basis' => 'Confirmation humaine',
      'copies' => @assets.map do |asset|
        { 'video_asset_id' => asset.id, 'record_id' => @record.id,
          'path' => asset.last_known_path, 'byte_size' => 1234 }
      end
    }
    @observer = lambda do |path|
      { path: path, byte_size: 1234, duration_minutes: 52, measured_duration_seconds: 3131.008,
        container: 'mp4', observed_at: Time.current,
        technical_details: { 'storage' => { 'uuid' => 'volume-test' },
                             'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'und' } }] } }
    end
  end

  test 'preview writes nothing' do
    assert_equal false, service.call[:applied]
    assert_nil @assets.first.reload.medium_id
    assert_empty @assets.first.technical_details
  end

  test 'confirmation preserves unidentified audio separately and does not edit record media' do
    service.call(apply: true)
    asset = @assets.first.reload
    assert_equal @medium.id, asset.medium_id
    assert_equal @language.id, asset.language_version_id
    assert_equal 'und', asset.technical_details.dig('streams', 0, 'tags', 'language')
    assert_equal 'Pascal', asset.technical_details.dig('confirmation', 'confirmed_by')
    assert_empty @record.reload.media
  end

  test 'rerun updates existing copies without creating duplicates' do
    service.call(apply: true)
    assert_no_difference('VideoAsset.count') { service.call(apply: true) }
  end

  test 'a changed path blocks the entire batch' do
    @assets.last.update!(last_known_path: '/videos/moved.m4v')
    assert_rejected
  end

  test 'a changed size blocks the entire batch' do
    @evidence['copies'].last['byte_size'] = 999
    assert_rejected
  end

  test 'a changed volume blocks the entire batch' do
    @evidence['storage_uuid'] = 'another-volume'
    assert_rejected
  end

  test 'deleted copies are never marked present again' do
    @assets.last.update!(status: 'deleted')
    assert_rejected
    assert_equal 'deleted', @assets.last.reload.status
  end

  test 'existing conflicting qualifications are preserved' do
    other = Medium.create!(short_name: 'OTHER', long_name: 'Autre support')
    @assets.last.update!(medium: other)
    assert_rejected
    assert_equal other.id, @assets.last.reload.medium_id
  end

  private

  def service
    CatalogEnrichment::ConfirmedCopyDetails.new(evidence: @evidence, observer: @observer)
  end

  def assert_rejected
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_nil @assets.first.reload.medium_id
    assert_empty @assets.first.technical_details
  end
end
