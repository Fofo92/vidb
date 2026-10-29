require 'test_helper'

class Tv::LibraryEpisodeAcquisitionsTest < ActiveSupport::TestCase
  Asset = Struct.new(:status, :broadcast_part_number) do
    def status_present?
      status == 'present'
    end
  end
  Episode = Struct.new(:id, :video_assets, :broadcast_part_count, :is_recorded)

  def evidence(assets, parts: 1, recorded: false, project_state: :associated)
    record = Episode.new(42, assets, parts, recorded)
    candidates = Object.new
    candidates.define_singleton_method(:call) { |_| { 7 => record } }
    projects = Object.new
    projects.define_singleton_method(:call) { |_| project_state }
    Tv::LibraryEpisodeAcquisitions.new(candidates: candidates, projects: projects).call([])[7]
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
  test 'available copies without projects are candidates for reencoding regardless of audio or subtitles' do
    result = evidence([Asset.new('present', nil)], project_state: :absent)
    assert_equal 'reencode', result.kind
    assert_match 'Réencodage souhaité', result.label
    assert_equal 'project_review', evidence([Asset.new('present', nil)], project_state: :unknown).kind
  end

  test 'all parts need project coverage before an episode is considered encoded with video_encoder' do
    first = Asset.new('present', 1)
    second = Asset.new('present', 2)
    record = Episode.new(42, [first, second], 2, true)
    candidates = Object.new
    candidates.define_singleton_method(:call) { |_| { 7 => record } }
    projects = Object.new
    projects.define_singleton_method(:call) { |asset| asset.broadcast_part_number == 1 ? :associated : :absent }
    detector = Tv::LibraryEpisodeAcquisitions.new(candidates: candidates, projects: projects)
    assert_equal 'reencode', detector.call([]).fetch(7).kind
    projects.define_singleton_method(:call) { |_| :associated }
    assert_equal 'available', detector.call([]).fetch(7).kind
  end

end
