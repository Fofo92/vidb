# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'json'

class SingleAudioPolicyTest < ActiveSupport::TestCase
  Copy = Struct.new(:id, :record_id, :record, :last_known_path, :byte_size, :technical_details,
                    :observed_at, :language_version_id, :language_version, keyword_init: true)
  Film = Struct.new(:complete_title, :language_version)

  setup do
    @directory = Dir.mktmpdir('vidb-language-', '/tmp')
    @old = 3.days.ago.to_time
    @asset = Copy.new(id: 1, record_id: 2, record: Film.new('Un film'), byte_size: 4,
                      observed_at: Time.current, last_known_path: "#{@directory}/film.mkv")
    prepare(nil)
  end

  teardown do
    FileUtils.remove_entry(@directory)
  end

  test 'single audio defaults to VF with explicit automatic provenance and no mutation' do
    before = @asset.to_h.deep_dup
    result = proposal
    assert_equal 'candidate', result[:status]
    assert_equal 'VF', result[:suggested_version]
    assert_equal 'single_audio_policy_v1', result[:basis]
    assert_match(/automatique/, result[:reason])
    assert_equal before, @asset.to_h
  end

  test 'an explicitly silent record avoids the VF default for a musical track' do
    @asset.record.language_version = LanguageVersion.new(short_name: 'MUET', long_name: 'Muet')
    prepare('fra')
    before = @asset.to_h.deep_dup
    result = proposal
    assert_equal 'candidate', result[:status]
    assert_equal 'MUET', result[:suggested_version]
    assert_equal 'declared_silent_work', result[:basis]
    assert_equal before, @asset.to_h
  end

  test 'the convention does not require a French language tag or a VF filename' do
    [nil, '', 'und', 'qaa', 'eng', 'fra'].each do |language|
      prepare(language)
      assert_equal 'VF', proposal[:suggested_version], language.inspect
    end
  end

  test 'explicit original versions in filename exclude the default even for hardcoded subtitles' do
    %w[VO VOST VOSTFR].each do |version|
      @asset.last_known_path = "#{@directory}/film_[#{version}].mkv"
      prepare('eng')
      assert_equal version.sub('VOSTFR', 'VOST'), proposal[:suggested_version]
    end
  end

  test 'an original version mentioned only in the record title also excludes the default' do
    @asset.record.complete_title = 'Film (VOST)'
    assert_equal 'VOST', proposal[:suggested_version]
    @asset.record.complete_title = 'Film VO'
    assert_equal 'VO', proposal[:suggested_version]
  end

  test 'contradictory title and filename are left for review' do
    @asset.record.complete_title = 'Film VOST'
    @asset.last_known_path = "#{@directory}/film_vf.mkv"
    prepare(nil)
    assert_equal 'needs_review', proposal[:status]
    assert_nil proposal[:suggested_version]
  end

  test 'an explicit original label conflicting with declared French audio needs review' do
    @asset.record.complete_title = 'Film VO'
    prepare('fra')
    assert_equal 'needs_review', proposal[:status]
  end

  test 'multiple unlabelled audio tracks and absent audio never use the shortcut' do
    prepare(nil, nil)
    assert_equal 'needs_review', proposal[:status]
    prepare
    assert_equal 'needs_review', proposal[:status]
  end

  test 'an interpreted project takes priority over the single audio shortcut' do
    prepare('qaa')
    project
    assert_equal 'VO', proposal[:suggested_version]
    assert_equal 'encoder_project_policy', proposal[:basis]
  end

  test 'a contradictory filename does not override a project' do
    @asset.last_known_path = "#{@directory}/film_vf.mkv"
    prepare('qaa')
    project
    assert_equal 'needs_review', proposal[:status]
  end

  test 'unreadable unsupported and incomplete companion projects prevent silent VF fallback' do
    ['{', JSON.generate({}), JSON.generate('format' => 'video_encoder.trim_project', 'version' => 2)].each do |text|
      path = Pathname.new(@asset.last_known_path).sub_ext('.json')
      path.write(text)
      File.utime(@old - 60, @old - 60, path)
      assert_equal 'needs_review', proposal[:status]
      assert_nil proposal[:suggested_version]
    end
  end

  test 'a newer project or changed copy prevents qualification' do
    project
    File.utime(Time.now, Time.now, Pathname.new(@asset.last_known_path).sub_ext('.json'))
    assert_equal 'needs_review', proposal[:status]
    project
    File.write(@asset.last_known_path, 'changed copy')
    assert_equal 'needs_review', proposal[:status]
  end

  test 'existing qualifications always take priority and remain unchanged' do
    @asset.language_version_id = 9
    @asset.language_version = Struct.new(:short_name).new('VOST')
    assert_equal 'already_qualified', proposal[:status]
    assert_equal 9, @asset.language_version_id
  end

  test 'a receipt must identify the actual project and copy' do
    prepare('qaa')
    project
    receipt = { 'format' => 'video_encoder.completed_export', 'version' => 1,
                'output_path' => @asset.last_known_path, 'byte_size' => 4,
                'modified_at' => File.stat(@asset.last_known_path).mtime.utc.iso8601(6),
                'project_sha256' => '0' * 64 }
    path = "#{@asset.last_known_path}.video_encoder-export.json"
    File.write(path, JSON.generate(receipt))
    assert_equal 'needs_review', proposal[:status]
    receipt['project_sha256'] = Digest::SHA256.file(Pathname.new(@asset.last_known_path).sub_ext('.json')).hexdigest
    File.write(path, JSON.generate(receipt))
    assert_equal 'VO', proposal[:suggested_version]
    assert_equal 'export_receipt_project_digest', proposal.dig(:encoder_evidence, :association)
    receipt['output_path'] = '/videos/other.mkv'
    File.write(path, JSON.generate(receipt))
    assert_equal 'needs_review', proposal[:status]
  end

  test 'a companion symlink cannot authorize qualification or the VF default' do
    json = Pathname.new(@asset.last_known_path).sub_ext('.json')
    File.symlink("#{@directory}/missing.json", json)
    assert_equal 'needs_review', proposal[:status]
    assert_nil proposal[:suggested_version]
  end

  test 'observed French and English without subtitles establish VM despite an old VF suffix' do
    @asset.last_known_path = "#{@directory}/film_vf.mkv"
    prepare('fre', 'eng')
    assert_equal 'VM', proposal[:suggested_version]
    assert_equal 'candidate', proposal[:status]
    assert_equal 'observed_multilingual_policy_v1', proposal[:basis]
    assert_nil @asset.language_version_id
  end

  test 'subtitles or ambiguous languages do not use the observed VM shortcut' do
    @asset.last_known_path = "#{@directory}/film_vf.mkv"
    prepare('fre', 'eng')
    @asset.technical_details['streams'] << { 'codec_type' => 'subtitle' }
    assert_equal 'needs_review', proposal[:status]
    prepare('fre', 'qaa')
    assert_equal 'needs_review', proposal[:status]
  end

  test 'original version markers are not overridden by the multilingual shortcut' do
    @asset.last_known_path = "#{@directory}/film_vost.mkv"
    prepare('fre', 'eng')
    assert_equal 'needs_review', proposal[:status]
  end

  private

  def proposal
    VideoAssets::LanguageProposal.new(@asset).call
  end

  def prepare(*languages)
    File.binwrite(@asset.last_known_path, 'copy')
    File.utime(@old, @old, @asset.last_known_path)
    @asset.technical_details = { 'observed_at' => Time.current.iso8601,
                                'streams' => languages.map do |language|
                                  { 'codec_type' => 'audio', 'tags' => { 'language' => language } }
                                end }
  end

  def project
    path = Pathname.new(@asset.last_known_path).sub_ext('.json')
    path.write(JSON.generate('format' => 'video_encoder.trim_project', 'version' => 2,
                            'sources' => [{ 'id' => 'one', 'inspection' => {
                              'audio_tracks' => [{ 'language' => 'qaa' }, { 'language' => 'fra' }]
                            } }], 'timeline' => [{ 'type' => 'segment', 'source_id' => 'one' }]))
    File.utime(@old - 60, @old - 60, path)
  end
end
