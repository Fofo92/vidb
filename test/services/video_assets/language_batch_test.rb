# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class LanguageBatchTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir('vidb-language-batch')
    @vf = LanguageVersion.find_or_create_by!(short_name: 'VF') { |version| version.long_name = 'Version française' }
    @observations = {}
    @copies = []
    @assets = []
    add_copy('one')
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test 'preview changes no qualification or provenance' do
    before = @assets.first.attributes
    report = service.call
    assert_equal false, report[:applied]
    assert_equal 1, report[:changes]
    assert_equal before, @assets.first.reload.attributes
  end

  test 'apply preserves prior details and records language evidence' do
    asset = @assets.first
    states = asset.record.attributes.slice('is_recorded', 'is_available', 'is_seen', 'is_checked')
    service.call(apply: true)
    assert_equal @vf.id, asset.reload.language_version_id
    assert_equal 'preserved', asset.technical_details['other_evidence']
    assert_equal 'Pascal', asset.technical_details.dig('language_qualification', 'decided_by')
    assert_equal states, asset.record.reload.attributes.slice(*states.keys)
    assert_equal 0, service.call(apply: true)[:changes]
  end

  test 'explicit confirmation qualifies an unlabelled track' do
    @copies.first.merge!('basis' => 'pascal_confirmation', 'declared_audio_languages' => [nil])
    @observations.values.first[:technical_details]['streams'].first['tags']['language'] = nil
    service.call(apply: true)
    assert_equal @vf.id, @assets.first.reload.language_version_id
  end

  test 'changed audio or storage stops the lot' do
    @observations.values.first[:technical_details]['streams'].first['tags']['language'] = 'eng'
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_nil @assets.first.reload.language_version_id
    @observations.values.first[:technical_details]['streams'].first['tags']['language'] = 'fra'
    @observations.values.first[:technical_details]['storage']['uuid'] = 'other-volume'
    assert_raises(ArgumentError) { service.call(apply: true) }
  end

  test 'a conflict on a later copy prevents changes to the first' do
    add_copy('two')
    @assets.last.update!(language_version: @vf)
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_nil @assets.first.reload.language_version_id
  end

  test 'a modified copy prevents application' do
    File.utime(Time.now, Time.now, @copies.first.fetch('path'))
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_nil @assets.first.reload.language_version_id
  end

  private

  def service
    evidence = { 'format' => 'vidb.video_asset_language_batch', 'version' => 1,
                 'decided_by' => 'Pascal', 'decided_on' => '2026-10-08',
                 'storage_uuid' => 'test-volume', 'copies' => @copies }
    VideoAssets::LanguageBatch.new(evidence: evidence, observer: ->(path) { @observations.fetch(path) })
  end

  def add_copy(name)
    record = Record.create!(french_title: name, language_version: @vf, record_kind: 'standalone_video')
    path = "#{@directory}/#{name}.mkv"
    File.write(path, 'copy')
    File.utime(3.days.ago.to_time, 3.days.ago.to_time, path)
    details = { 'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'fra' } }],
                'storage' => { 'uuid' => 'test-volume' }, 'observed_at' => Time.current.iso8601 }
    asset = VideoAsset.create!(record: record, last_known_path: path, byte_size: 4,
                               technical_details: details.merge('other_evidence' => 'preserved'))
    @assets << asset
    @observations[path] = { path: path, byte_size: 4, technical_details: details }
    @copies << { 'video_asset_id' => asset.id, 'record_id' => record.id, 'path' => path, 'byte_size' => 4,
                 'observed_at' => details['observed_at'], 'declared_audio_languages' => ['fra'],
                 'basis' => 'language_proposal_v2', 'language_version' => 'VF', 'reason' => 'Test' }
  end
end
