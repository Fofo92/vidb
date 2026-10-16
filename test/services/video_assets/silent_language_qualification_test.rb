# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class SilentLanguageQualificationTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir('vidb-silent-', '/tmp')
    @silent = LanguageVersion.find_or_create_by!(short_name: 'MUET') { |version| version.long_name = 'Muet' }
    @vf = LanguageVersion.find_or_create_by!(short_name: 'VF') { |version| version.long_name = 'Version française' }
    @record = Record.create!(french_title: 'Film muet test', language_version: @silent, record_kind: 'standalone_video')
    @path = "#{@directory}/film_vf.mkv"
    File.binwrite(@path, 'copy')
    old = 3.days.ago.to_time
    File.utime(old, old, @path)
    @asset = VideoAsset.create!(record: @record, last_known_path: @path, byte_size: 4)
    @streams = [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'fra' } }]
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test 'musical audio and a legacy VF suffix do not turn a declared silent work into VF' do
    proposal = propose
    assert_equal 'candidate', proposal[:status]
    assert_equal 'MUET', proposal[:suggested_version]
    assert_equal 'declared_silent_work', proposal[:basis]
    assert_nil @asset.reload.language_version_id
  end

  test 'a silent work can have no audio or several accompaniment tracks' do
    [[], @streams * 2].each do |streams|
      @streams = streams
      assert_equal 'MUET', propose[:suggested_version]
    end
  end

  test 'lack of audio alone does not identify a silent work' do
    @record.update!(language_version: @vf)
    @streams = []
    assert_equal 'needs_review', propose[:status]
    assert_nil @asset.reload.language_version_id
  end

  test 'an existing copy qualification is preserved even when the record is silent' do
    @asset.update!(language_version: @vf)
    assert_equal 'already_qualified', propose[:status]
    assert_equal @vf.id, @asset.reload.language_version_id
  end

  test 'a missing final copy stays under review even for a silent record' do
    File.unlink(@path)
    assert_equal 'needs_review', propose[:status]
    assert_nil @asset.reload.language_version_id
  end

  test 'preview and apply preserve the record and retain explicit silent provenance' do
    original = @record.attributes
    assert_equal 1, service.call(asset_id: @asset.id)[:changes]
    assert_nil @asset.reload.language_version_id
    assert_equal 1, service.call(asset_id: @asset.id, apply: true)[:changes]
    assert_equal @silent.id, @asset.reload.language_version_id
    assert_equal 'declared_silent_work', @asset.technical_details.dig('language_qualification', 'basis')
    assert_equal original, @record.reload.attributes
    assert_equal 'already_qualified', service.call(asset_id: @asset.id, apply: true)[:status]
  end

  test 'a changed file cannot receive an automatic silent qualification' do
    File.binwrite(@path, 'changed')
    result = service.call(asset_id: @asset.id, apply: true)
    assert_equal 'needs_review', result[:status]
    assert_equal false, result[:applied]
    assert_nil @asset.reload.language_version_id
  end

  private

  def propose
    @asset.update!(technical_details: { 'streams' => @streams })
    VideoAssets::LanguageProposal.new(@asset).call
  end

  def service
    observer = lambda do |_path|
      { path: @path, byte_size: File.size(@path), observed_at: Time.current,
        technical_details: { 'streams' => @streams.deep_dup,
                             'storage' => { 'uuid' => VideoAssets::ReconciliationVolumeGuard::UUID } } }
    end
    VideoAssets::AutomaticLanguageQualification.new(root: @directory, volume_guard: -> {}, observer: observer)
  end
end
