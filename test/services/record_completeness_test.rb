require 'test_helper'

class RecordCompletenessTest < ActiveSupport::TestCase
  Item = Struct.new(:id, :record_kind, :ancestor_ids, :video_assets, :broadcast_part_count, :is_available)
  Copy = Struct.new(:status, :broadcast_part_number) do
    def status_present?
      status == 'present'
    end
  end

  def item(id, kind, parents = [], copies: [], parts: 1, available: true)
    Item.new(id, kind, parents, copies, parts, available)
  end

  def filter(records, state)
    RecordCompleteness.new(records: records).ids(state)
  end

  def present(part = nil)
    Copy.new('present', part)
  end

  test 'series and season are complete when every known episode has a present copy' do
    records = [item(1, 'series'), item(2, 'season', [1]),
               item(3, 'episode', [1, 2], copies: [present]), item(4, 'episode', [1, 2], copies: [present])]
    assert_equal [1, 2], filter(records, 'complete')
    assert_empty filter(records, 'incomplete')
  end

  test 'legacy available flags never replace copies present on disk' do
    records = [item(1, 'collection'), item(2, 'standalone_video', [1], available: true)]
    assert_empty filter(records, 'complete')
    assert_equal [1], filter(records, 'incomplete')
  end

  test 'present copies override legacy false flags' do
    records = [item(1, 'collection'), item(2, 'standalone_video', [1], copies: [present], available: false)]
    assert_equal [1], filter(records, 'complete')
  end

  test 'missing and deleted copies do not make an ensemble complete' do
    %w[missing deleted].each do |status|
      records = [item(1, 'series'), item(2, 'episode', [1], copies: [Copy.new(status, nil)])]
      assert_equal [1], filter(records, 'incomplete')
    end
  end

  test 'one present encoding is sufficient despite other missing or deleted copies' do
    records = [item(1, 'series'), item(2, 'episode', [1], copies: [Copy.new('missing', nil), present])]
    assert_equal [1], filter(records, 'complete')
  end

  test 'duplicate encodings of one episode cannot compensate for another missing episode' do
    records = [item(1, 'series'), item(2, 'episode', [1], copies: [present, present]), item(3, 'episode', [1])]
    assert_equal [1], filter(records, 'incomplete')
    assert_empty filter(records, 'complete')
  end

  test 'nested collections use all descendant works' do
    records = [item(1, 'collection'), item(2, 'collection', [1]),
               item(3, 'standalone_video', [1, 2], copies: [present]), item(4, 'standalone_video', [1])]
    assert_equal [2], filter(records, 'complete')
    assert_equal [1], filter(records, 'incomplete')
  end

  test 'an empty collection or series is undetermined rather than vacuously complete' do
    records = [item(1, 'series'), item(2, 'collection')]
    assert_equal [1, 2], filter(records, 'unknown')
    assert_empty filter(records, 'complete')
  end

  test 'an empty season prevents claiming a whole series complete' do
    records = [item(1, 'series'), item(2, 'season', [1]), item(3, 'season', [1]),
               item(4, 'episode', [1, 2], copies: [present])]
    assert_equal [2], filter(records, 'complete')
    assert_equal [1, 3], filter(records, 'unknown')
  end

  test 'all physical parts of an episode are needed or one whole copy' do
    records = [item(1, 'series'), item(2, 'episode', [1], copies: [present(1), present(1)], parts: 2)]
    assert_equal [1], filter(records, 'incomplete')
    records.last.video_assets << present(2)
    assert_equal [1], filter(records, 'complete')
    records.last.video_assets = [present]
    assert_equal [1], filter(records, 'complete')
  end

  test 'individual works and episodes are not returned as ensembles' do
    assert_empty filter([item(1, 'episode', copies: [present]), item(2, 'standalone_video', copies: [present])], 'complete')
  end

  test 'invalid states are rejected' do
    assert_raises(ActiveRecord::RecordNotFound) { filter([], 'invalid') }
  end
end
