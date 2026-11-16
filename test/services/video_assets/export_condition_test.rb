require 'test_helper'

class VideoAssets::ExportConditionTest < ActiveSupport::TestCase
  def declaration(**changes)
    { 'integrality' => 'complete', 'damage' => 'none', 'retained_portion' => 'unknown', 'note' => '',
      'declared_at' => Time.current.iso8601, 'source_paths' => ['/commun/source.m2t'],
      'affected_source_paths' => [] }.merge(changes.stringify_keys)
  end

  test 'old receipts keep legacy condition semantics' do
    assert_equal({}, VideoAssets::ExportCondition.call({}))
  end

  test 'damage and integrality are independent and no retained duration is inferred' do
    values = VideoAssets::ExportCondition.call('copy_condition' => declaration(damage: 'severe'))
    details = values.fetch(:condition_details)
    assert_equal 'complete', details['integrality']
    assert_equal 'severe', details['damage']
    assert_not details.key?('retained_duration_seconds')
  end

  test 'both known portions of an incomplete copy are accepted' do
    %w[beginning end unknown].each do |portion|
      value = declaration(integrality: 'incomplete', retained_portion: portion)
      assert_equal portion, VideoAssets::ExportCondition.call('copy_condition' => value)
                                                      .fetch(:condition_details)['retained_portion']
    end
  end

  test 'invalid declarations never silently become complete copies' do
    [nil, {}, declaration(damage: 'bad'), declaration(integrality: 'unknown'),
     declaration(retained_portion: 'end'), declaration(note: 'x' * 2001),
     declaration(source_paths: nil), declaration(affected_source_paths: ['/commun/other.m2t']),
     declaration(declared_at: 'yesterday')].each do |value|
      assert_raises(ArgumentError) { VideoAssets::ExportCondition.call('copy_condition' => value) }
    end
  end
end
