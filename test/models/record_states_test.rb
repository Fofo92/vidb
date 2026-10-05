# frozen_string_literal: true

require 'test_helper'

class RecordStatesTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @series = create_record('Série', record_kind: 'series', year: 1990, is_seen: true, is_available: true)
    @season = create_record('Saison 01', parent: @series, record_kind: 'season', year: 1991, rank: 1)
    @first = create_record('Premier', parent: @season, record_kind: 'episode', year: 2020, rank: 1)
    @second = create_record('Deuxième', parent: @season, record_kind: 'episode', year: 2022, rank: 2)
  end

  test 'counts only leaves and ignores parent scalar flags and years' do
    @first.update!(is_seen: true)
    counts = @series.state_counts
    assert_equal 2, counts[:is_seen][:total]
    assert_equal 1, counts[:is_seen][:yes]
    assert_equal 1, counts[:is_seen][:unknown]
    assert_equal 0, counts[:is_available][:yes]
    assert_equal '2020-2022', @series.display_range_of_years
    assert_equal '2020-2022', @season.display_range_of_years
  end

  test 'unverified false remains unknown but checked false is known negative' do
    @first.update!(is_seen: false, is_checked: false)
    assert_nil @first.effective_state(:is_seen)
    @first.update!(is_checked: true)
    assert_equal false, @first.effective_state(:is_seen)
  end

  test 'available implies recorded and historical recording cannot be cleared' do
    @first.update!(is_available: true)
    assert_equal true, @first.reload.is_recorded
    @first.update!(is_available: false, is_recorded: false)
    assert_equal true, @first.reload.is_recorded
    assert_equal false, @first.is_available
  end

  test 'last deleted asset clears availability but preserves recording history' do
    asset = VideoAsset.create!(record: @first, last_known_path: '/videos/states.mkv')
    assert_equal true, @first.reload.is_available
    assert_equal true, @first.is_recorded
    asset.update!(status: 'deleted')
    assert_equal false, @first.reload.is_available
    assert_equal true, @first.is_recorded
    assert_equal false, @first.effective_state(:is_available)
  end

  test 'deleting one of several copies does not clear availability' do
    first = VideoAsset.create!(record: @first, last_known_path: '/videos/states-a.mkv')
    VideoAsset.create!(record: @first, last_known_path: '/videos/states-b.mkv')
    first.update!(status: 'deleted')
    assert_equal true, @first.reload.is_available
  end

  test 'confirmed copies prevent manual false availability' do
    VideoAsset.create!(record: @first, last_known_path: '/videos/states-c.mkv')
    @first.reload.update!(is_available: false)
    assert_equal true, @first.reload.is_available
  end

  test 'empty containers are not counted as episodes' do
    empty = create_record('Saison vide', parent: @series, record_kind: 'season', rank: 2)
    assert_equal 2, @series.state_counts[:is_recorded][:total]
    assert_equal 0, empty.state_counts[:is_recorded][:total]
  end

  test 'a confirmed asset cannot silently change owners' do
    asset = VideoAsset.create!(record: @first, last_known_path: '/videos/states-d.mkv')
    assert_not asset.update(record: @second)
    assert_equal @first.id, asset.reload.record_id
  end

  private

  def create_record(title, attributes = {})
    Record.create!({ french_title: title, language_version: @language }.merge(attributes))
  end
end
