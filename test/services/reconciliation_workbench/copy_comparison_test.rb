require 'test_helper'

class ReconciliationWorkbenchCopyComparisonTest < ActiveSupport::TestCase
  def sample(id, bytes:, date:, audio:, subtitles: [], encoder: false)
    streams = [{ 'codec_type' => 'video', 'width' => 1920, 'height' => 1080 }]
    streams += audio.map { |language| { 'codec_type' => 'audio', 'channels' => 2, 'tags' => { 'language' => language } } }
    streams += subtitles.map { |language| { 'codec_type' => 'subtitle', 'tags' => { 'language' => language } } }
    { 'asset_id' => id, 'modified_at' => date, 'encoder_verified' => encoder,
      'measurement' => { 'byte_size' => bytes, 'measured_duration_seconds' => 1320.0,
                         'technical_details' => { 'streams' => streams } } }
  end

  setup do
    @old = sample(1, bytes: 1000, date: '2021-01-01T00:00:00Z', audio: ['fra'])
    @new = sample(2, bytes: 800, date: '2026-10-01T00:00:00Z', audio: %w[fr eng], subtitles: ['fra'], encoder: true)
  end

  def result
    ReconciliationWorkbench::CopyComparison.new.call([@old, @new])
  end

  def streams(copy)
    copy['measurement']['technical_details']['streams']
  end

  test 'prefers the newer richer smaller export while stating that visual quality is unmeasured' do
    assert result['eligible']
    assert_equal 2, result['preferred_asset_id']
    assert_equal false, result['quality_assessed']
  end

  test 'a smaller recent file alone is insufficient' do
    streams(@new).reject! { |stream| stream.dig('tags', 'language') == 'eng' || stream['codec_type'] == 'subtitle' }
    assert_not result['eligible']
  end

  test 'losing the previous audio language prevents automatic preference' do
    streams(@new).reject! { |stream| stream.dig('tags', 'language') == 'fr' }
    assert_not result['eligible']
  end

  test 'losing a subtitle or its forced role prevents automatic preference' do
    streams(@old) << { 'codec_type' => 'subtitle', 'tags' => { 'language' => 'fra' }, 'disposition' => { 'forced' => 1 } }
    assert_not result['eligible']
    streams(@new) << streams(@old).last.deep_dup
    assert result['eligible']
  end

  test 'unknown languages are not inferred from a VM label or filename' do
    streams(@old).last['tags']['language'] = 'und'
    assert_not result['eligible']
    assert_match 'inconnue', result['reason']
  end

  test 'private original language tags do not establish the actual language' do
    streams(@new).last['tags']['language'] = 'qaa'
    assert_not result['eligible']
  end

  test 'a recently copied file without verified encoder evidence is not preferred automatically' do
    @new['encoder_verified'] = false
    assert_not result['eligible']
  end

  test 'an older or larger export is not preferred automatically' do
    @new['modified_at'] = '2020-01-01T00:00:00Z'
    assert_not result['eligible']
    @new['modified_at'] = '2026-10-01T00:00:00Z'
    @new['measurement']['byte_size'] = 1001
    assert_not result['eligible']
  end

  test 'a large duration difference remains an arbitration including advertisement trimming' do
    @new['measurement']['measured_duration_seconds'] = 1200.0
    assert_not result['eligible']
    @new['measurement']['measured_duration_seconds'] = 1318.0
    assert result['eligible']
    @new['measurement']['measured_duration_seconds'] = 1317.9
    assert_not result['eligible']
  end

  test 'lower definition or fewer audio channels does not pass the automatic rule' do
    streams(@new).first['height'] = 720
    assert_not result['eligible']
    streams(@new).first['height'] = 1080
    streams(@old).last['channels'] = 6
    assert_not result['eligible']
  end

  test 'an extra commentary alone is not considered another useful language version' do
    streams(@new).replace(streams(@old).deep_dup)
    streams(@new) << { 'codec_type' => 'audio', 'channels' => 2, 'tags' => { 'language' => 'eng' },
                       'disposition' => { 'comment' => 1 } }
    assert_not result['eligible']
  end

  test 'an existing commentary is retained even though it does not itself make a copy richer' do
    streams(@old) << { 'codec_type' => 'audio', 'channels' => 2, 'tags' => { 'language' => 'fra' },
                       'disposition' => { 'comment' => 1 } }
    assert_not result['eligible']
    streams(@new) << streams(@old).last.deep_dup
    assert result['eligible']
  end

  test 'several incomparable versions do not get an arbitrary winner' do
    third = sample(3, bytes: 750, date: '2026-10-02T00:00:00Z', audio: %w[fra deu], encoder: true)
    comparison = ReconciliationWorkbench::CopyComparison.new.call([@old, @new, third])
    assert_not comparison['eligible']
  end
end
