# frozen_string_literal: true

require 'test_helper'

class BroadcastPartStatesTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IN', long_name: 'Indéterminée')
    series = Record.create!(french_title: 'Série test', record_kind: 'series', language_version: language)
    season = series.children.create!(french_title: 'Saison 01', record_kind: 'season', rank: 1,
                                     language_version: language)
    @record = season.children.create!(french_title: 'Épisode test', record_kind: 'episode', rank: 1,
                                      language_version: language, broadcast_part_count: 2,
                                      is_recorded: nil, is_available: false)
  end

  test 'both complementary parts are required and recording history survives deletion' do
    first = copy(1, 'one', 40)
    assert_not @record.reload.is_available
    assert_not @record.is_recorded
    second = copy(2, 'two', 42)
    assert @record.reload.is_available
    assert @record.is_recorded
    second.update!(status: 'deleted')
    assert_not @record.reload.is_available
    assert @record.is_recorded
    first.update!(status: 'deleted')
    assert_not @record.reload.is_available
    assert @record.is_recorded
  end

  test 'duplicate encodings of part one cannot complete the episode' do
    copy(1, 'one', 40)
    copy(1, 'alternative', 41)
    assert_not @record.reload.is_available
    copy(2, 'two', 42)
    assert @record.reload.is_available
  end

  test 'whole copy remains sufficient without complementary parts' do
    copy(nil, 'whole', 82)
    assert @record.reload.is_available
    assert @record.is_recorded
  end

  test 'duration adds complementary parts and treats encodings as alternatives' do
    first = copy(1, 'one', 40)
    second = copy(2, 'two', 42)
    assert_equal [82, 82], duration([first, second])
    alternative = copy(1, 'alternative', 41)
    assert_equal [82, 83], duration([first, second, alternative])
    whole = copy(nil, 'whole', 84)
    assert_equal [82, 84], duration([first, second, alternative, whole])
    assert_nil duration([first])
  end

  test 'precise part durations are summed before rounding' do
    first = copy(1, 'one', 40)
    second = copy(2, 'two', 40)
    first.update!(technical_details: { measured_duration_seconds: 2429.0 })
    second.update!(technical_details: { measured_duration_seconds: 2429.0 })
    assert_equal [81, 81], duration([first.reload, second.reload])
  end

  test 'part identity is immutable and cannot exceed declared count' do
    first = copy(1, 'one', 40)
    assert_not first.update(broadcast_part_number: 2)
    asset = @record.video_assets.build(last_known_path: '/test/invalid', broadcast_part_number: 3)
    assert_not asset.valid?
  end

  private

  def copy(number, name, minutes)
    @record.video_assets.create!(last_known_path: "/test/#{name}.mkv", status: 'present',
                                 broadcast_part_number: number, duration_minutes: minutes)
  end

  def duration(assets)
    VideoAssets::PartDuration.range(assets, expected_parts: 2)
  end
end
