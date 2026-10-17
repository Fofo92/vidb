# frozen_string_literal: true
require 'test_helper'

class IdentifiedMultilingualDecisionTest < ActiveSupport::TestCase
  def audio(language, disposition = {})
    { 'codec_type' => 'audio', 'tags' => { 'language' => language }, 'disposition' => disposition }
  end

  def decide(streams, versions = ['VF'], title_versions = [])
    VideoAssets::ObservedMultilingualDecision.new(streams,
      { versions: versions, title_versions: title_versions }).call
  end

  test 'French and English remain multilingual despite a legacy VF suffix' do
    assert_equal ['candidate', 'VM'], decide([audio('fre'), audio('eng')]).first(2)
  end

  test 'French and German bibliographic and terminological codes establish VM' do
    %w[ger deu de].each do |language|
      assert_equal ['candidate', 'VM'], decide([audio('fra'), audio(language)]).first(2)
    end
  end

  test 'identified Spanish and several identified dialogue languages establish VM' do
    assert_equal 'VM', decide([audio('fr'), audio('es')])[1]
    assert_equal 'VM', decide([audio('fre'), audio('eng'), audio('ger')])[1]
  end

  test 'an explicit VO or VOST mention or conflicting filename is preserved for review' do
    [%w[VO], %w[VOST], %w[VMST], %w[VF VM]].each do |versions|
      assert_nil decide([audio('fra'), audio('deu')], versions)
    end
    assert_nil decide([audio('fra'), audio('deu')], ['VF'], ['VO'])
  end

  test 'subtitles keep the copy outside the policy' do
    assert_nil decide([audio('fre'), audio('eng'), { 'codec_type' => 'subtitle' }])
  end

  test 'unknown missing reserved or unsupported language codes do not establish VM' do
    ['', nil, 'und', 'qaa', 'mul', 'zxx', 'xyz'].each do |language|
      assert_nil decide([audio('fre'), audio('eng'), audio(language)])
    end
  end

  test 'one dialogue language or two foreign languages do not establish VM' do
    assert_nil decide([audio('fra')])
    assert_nil decide([audio('fre'), audio('fra')])
    assert_nil decide([audio('eng'), audio('deu')])
    assert_nil decide([])
  end

  test 'commentary and audio description cannot establish another dialogue language' do
    %w[comment visual_impaired descriptions].each do |name|
      assert_nil decide([audio('fra'), audio('deu', name => 1)])
    end
  end

  test 'no filename marker and an explicit VM marker both allow identified tracks' do
    assert_equal 'VM', decide([audio('fre'), audio('ger')], [])[1]
    assert_equal 'VM', decide([audio('fre'), audio('ger')], ['VM'])[1]
  end
end
