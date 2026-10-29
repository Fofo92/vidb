require 'test_helper'

class Tv::LibraryEpisodeAcquisitionsTest < ActiveSupport::TestCase
  Asset = Struct.new(:status, :broadcast_part_number) do
    def status_present?
      status == 'present'
    end
  end
  Episode = Struct.new(:id, :video_assets, :broadcast_part_count, :is_recorded)

  def evidence(assets, parts: 1, recorded: false)
    record = Episode.new(42, assets, parts, recorded)
    candidates = Object.new
    candidates.define_singleton_method(:call) { |_| { 7 => record } }
    Tv::LibraryEpisodeAcquisitions.new(candidates: candidates).call([])[7]
  end

  test 'a completed copy is acquired independently of capture history or source paths' do
    result = evidence([Asset.new('present', nil)])
    assert_equal 'available', result.kind
    assert_equal 42, result.record_id
  end

  test 'missing and deleted copies remain historical acquisitions rather than available copies' do
    %w[missing deleted].each do |status|
      result = evidence([Asset.new(status, nil)])
      assert_equal 'history', result.kind
      assert_match 'indisponible', result.label
    end
  end

  test 'duplicate encodings of one part do not count as a complete episode' do
    part = Asset.new('present', 1)
    assert_nil evidence([part, part.dup], parts: 2, recorded: true)
    complete = evidence([part, Asset.new('present', 2)], parts: 2)
    assert_equal 'available', complete.kind
    incomplete_now = evidence([part, Asset.new('missing', 2)], parts: 2)
    assert_equal 'history', incomplete_now.kind
  end

  test 'legacy recording flags are distinguished from present copies' do
    assert_equal 'recorded', evidence([], recorded: true).kind
    assert_nil evidence([], recorded: false)
    assert_nil evidence([], recorded: nil)
  end
end
