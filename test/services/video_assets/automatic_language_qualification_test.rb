# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class AutomaticLanguageQualificationTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir('vidb-language-', '/tmp')
    @vf = LanguageVersion.find_or_create_by!(short_name: 'VF') { |version| version.long_name = 'Version française' }
    record = Record.create!(french_title: 'Qualification automatique', record_kind: 'standalone_video', language_version: @vf)
    @path = "#{@directory}/film.mkv"
    File.binwrite(@path, 'copy')
    old = 3.days.ago.to_time
    File.utime(old, old, @path)
    @asset = VideoAsset.create!(record: record, last_known_path: @path, byte_size: 4,
                               technical_details: { 'preserved' => true })
    @observed = { path: @path, byte_size: 4, observed_at: Time.current,
                  technical_details: { 'streams' => [{ 'codec_type' => 'audio' }],
                                       'storage' => { 'uuid' => VideoAssets::ReconciliationVolumeGuard::UUID } } }
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test 'preview writes neither language nor provenance' do
    before = @asset.attributes
    assert_equal 1, service.call(asset_id: @asset.id)[:changes]
    assert_equal before, @asset.reload.attributes
  end

  test 'apply records automatic provenance preserves catalogue and is idempotent' do
    before = @asset.record.attributes
    assert_equal 1, service.call(asset_id: @asset.id, apply: true)[:changes]
    assert_equal @vf.id, @asset.reload.language_version_id
    qualification = @asset.technical_details.fetch('language_qualification')
    assert_equal 'single_audio_policy_v1', qualification['basis']
    assert_equal 'vidb (politique automatique)', qualification['decided_by']
    assert_equal false, qualification.dig('source_report', 'manual_listening')
    assert_equal true, @asset.technical_details['preserved']
    assert_equal before, @asset.record.reload.attributes
    assert_equal 'already_qualified', service.call(asset_id: @asset.id, apply: true)[:status]
  end

  test 'an existing different qualification is preserved' do
    other = LanguageVersion.create!(short_name: 'ORIG', long_name: 'Version existante')
    @asset.update!(language_version: other)
    assert_equal 'already_qualified', service.call(asset_id: @asset.id, apply: true)[:status]
    assert_equal other.id, @asset.reload.language_version_id
  end

  test 'unresolved audio produces a review result without writing' do
    @observed[:technical_details]['streams'] << { 'codec_type' => 'audio' }
    assert_equal 'needs_review', service.call(asset_id: @asset.id, apply: true)[:status]
    assert_nil @asset.reload.language_version_id
  end

  test 'unexpected storage and changed size prevent application' do
    @observed[:technical_details]['storage']['uuid'] = 'different'
    assert_raises(ArgumentError) { service.call(asset_id: @asset.id, apply: true) }
    @observed[:technical_details]['storage']['uuid'] = VideoAssets::ReconciliationVolumeGuard::UUID
    File.binwrite(@path, 'changed file')
    assert_raises(ArgumentError) { service.call(asset_id: @asset.id, apply: true) }
    assert_nil @asset.reload.language_version_id
  end

  test 'deleted copies and symlink copies cannot be qualified' do
    @asset.update!(status: 'deleted')
    assert_raises(ArgumentError) { service.call(asset_id: @asset.id, apply: true) }
    @asset.update!(status: 'present')
    File.rename(@path, "#{@path}.real")
    File.symlink("#{@path}.real", @path)
    assert_raises(ArgumentError) { service.call(asset_id: @asset.id, apply: true) }
    assert_nil @asset.reload.language_version_id
  end

  test 'a changed second probe prevents writing even if the proposed version remains VF' do
    calls = 0
    observer = lambda do |_path|
      calls += 1
      result = @observed.deep_dup
      result[:technical_details]['streams'].first['tags'] = { 'language' => 'fra' } if calls > 1
      result
    end
    qualifier = VideoAssets::AutomaticLanguageQualification.new(root: @directory, volume_guard: -> {}, observer: observer)
    assert_raises(ArgumentError) { qualifier.call(asset_id: @asset.id, apply: true) }
    assert_nil @asset.reload.language_version_id
    assert_nil @asset.technical_details['language_qualification']
  end

  test 'French and English without subtitles can be applied automatically despite a VF filename' do
    @vm = LanguageVersion.find_or_create_by!(short_name: 'VM') { |version| version.long_name = 'Version multilingue' }
    old_path = @path
    @path = "#{@directory}/film_vf.mkv"
    File.rename(old_path, @path)
    @asset.update!(last_known_path: @path)
    @observed[:path] = @path
    @observed[:technical_details]['streams'] = %w[fre eng].map do |language|
      { 'codec_type' => 'audio', 'tags' => { 'language' => language } }
    end
    assert_equal 1, service.call(asset_id: @asset.id, apply: true)[:changes]
    assert_equal @vm.id, @asset.reload.language_version_id
    assert_equal 'observed_multilingual_policy_v1', @asset.technical_details.dig('language_qualification', 'basis')
    assert_equal @path, @asset.last_known_path
  end

  private

  def service
    VideoAssets::AutomaticLanguageQualification.new(root: @directory, volume_guard: -> {},
                                                    observer: ->(_path) { @observed.deep_dup })
  end
end
