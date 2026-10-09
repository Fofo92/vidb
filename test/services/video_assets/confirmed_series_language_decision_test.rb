# frozen_string_literal: true

require 'test_helper'

class ConfirmedSeriesLanguageDecisionTest < ActiveSupport::TestCase
  Asset = Struct.new(:last_known_path, :technical_details)

  test 'explicit scoped confirmation qualifies one unlabelled French legacy track' do
    result = decision('und')
    assert_equal 'candidate', result[:status]
    assert_equal 'VF', result[:suggested_version]
    assert_equal 'pascal_confirmation', result[:basis]
  end

  test 'unknown projects and original filename markers cannot be overridden' do
    assert_equal 'needs_review', decision('und', encoder: 'unsupported_project')[:status]
    assert_equal 'needs_review', decision('und', versions: ['VOST'])[:status]
    assert_equal 'needs_review', decision('und', versions: %w[VF VO])[:status]
  end

  test 'foreign or original-role audio alone does not become French' do
    assert_equal 'needs_review', decision('ita')[:status]
    assert_equal 'needs_review', decision('qaa')[:status]
  end

  test 'matched encoder policy is preserved rather than replaced with VF' do
    proposal = { status: 'candidate', suggested_version: 'VMST', encoder_evidence: { status: 'matched' } }
    asset = Asset.new('/test/part.mkv', { 'streams' => [] })
    assert_equal proposal, VideoAssets::ConfirmedSeriesLanguageDecision.call(proposal, asset)
  end

  private

  def decision(language, encoder: 'absent', versions: [])
    asset = Asset.new('/test/part.mkv', {
      'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => language } }]
    })
    proposal = { status: 'needs_review', suggested_version: nil, encoder_evidence: { status: encoder },
                 filename_evidence: { versions: versions } }
    VideoAssets::ConfirmedSeriesLanguageDecision.call(proposal, asset)
  end
end
