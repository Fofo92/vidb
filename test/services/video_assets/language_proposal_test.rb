# frozen_string_literal: true

require 'test_helper'

class LanguageProposalTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'PROP', long_name: 'Version test')
    record = Record.create!(french_title: 'Test langues', language_version: language,
                            record_kind: 'standalone_video')
    @asset = VideoAsset.create!(record: record, last_known_path: '/videos/test-langues.mkv')
  end

  test 'French audio proposes VF without writing qualification' do
    report = propose('fra')
    assert_equal 'VF', report[:suggested_version]
    assert_equal 'candidate', report[:status]
    assert_nil @asset.reload.language_version_id
  end

  test 'French aliases agree and multiple same-language tracks do not imply VM' do
    assert_equal 'VF', propose('fre', 'fr')[:suggested_version]
  end

  test 'French and English propose VM' do
    assert_equal 'VM', propose('fra', 'eng')[:suggested_version]
  end

  test 'unknown audio language blocks a proposal even alongside French' do
    assert_equal 'needs_review', propose('fra', 'und')[:status]
    assert_nil propose('qaa')[:suggested_version]
  end

  test 'foreign audio alone does not prove original version' do
    assert_nil propose('eng')[:suggested_version]
  end

  test 'missing audio and existing qualification remain explicit' do
    assert_equal 'needs_review', propose[:status]
    @asset.update!(language_version: @asset.record.language_version)
    assert_equal 'already_qualified', propose('fra')[:status]
    assert_equal 'PROP', @asset.reload.language_version.short_name
  end

  private

  def propose(*languages)
    @asset.update!(technical_details: {
                     'streams' => languages.map { |value| { 'codec_type' => 'audio', 'tags' => { 'language' => value } } }
                   })
    VideoAssets::LanguageProposal.new(@asset).call
  end
end
