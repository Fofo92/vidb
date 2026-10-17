require 'test_helper'

class ReconciliationWorkbenchCopySuggestionTest < ActiveSupport::TestCase
  def sample(id, bytes, date, languages, subtitles)
    streams = [{ 'codec_type' => 'video', 'width' => 1920, 'height' => 1080 }]
    streams += languages.map { |language| { 'codec_type' => 'audio', 'tags' => { 'language' => language }, 'channels' => 2 } }
    streams += subtitles.map { |language| { 'codec_type' => 'subtitle', 'tags' => { 'language' => language } } }
    { 'asset_id' => id, 'modified_at' => date, 'encoder_verified' => false,
      'measurement' => { 'byte_size' => bytes, 'measured_duration_seconds' => 1320,
                         'technical_details' => { 'streams' => streams } } }
  end

  setup do
    @old = sample(1, 1000, '2021-01-01T00:00:00Z', %w[fre eng], [])
    @new = sample('candidate', 800, '2026-01-01T00:00:00Z', %w[fra qaa], ['fra'])
    @payload = { 'samples' => [@old, @new], 'comparison' => { 'eligible' => false } }
  end

  test 'Panique style evidence suggests the newer copy but never makes unknown languages automatically eligible' do
    assert_equal 'candidate', ReconciliationWorkbench::CopySuggestion.call(@payload)
    assert_not ReconciliationWorkbench::CopyComparison.new.call([@old, @new])['eligible']
    assert_equal 'qaa', @new.dig('measurement', 'technical_details', 'streams', 2, 'tags', 'language')
  end

  test 'size and age alone or differing duration do not produce a preselected suggestion' do
    @new['measurement']['measured_duration_seconds'] = 1400
    assert_nil ReconciliationWorkbench::CopySuggestion.call(@payload)
    @new['measurement']['measured_duration_seconds'] = 1320
    @new['measurement']['technical_details']['streams'].pop
    assert_nil ReconciliationWorkbench::CopySuggestion.call(@payload)
  end

  test 'no measurements produce no suggestion' do
    assert_nil ReconciliationWorkbench::CopySuggestion.call({})
  end
end
