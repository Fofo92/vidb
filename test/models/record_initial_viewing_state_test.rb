# frozen_string_literal: true

require 'test_helper'

class RecordInitialViewingStateTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
  end

  test 'new videos are confirmed unseen by default' do
    %w[standalone_video episode undetermined].each do |kind|
      record = create_record(record_kind: kind)
      assert_equal false, record.is_seen
      assert_not_nil record.seen_state_confirmed_at
      assert_equal false, record.reload.effective_state(:is_seen)
    end
  end

  test 'containers do not receive a scalar viewing confirmation' do
    %w[series season].each do |kind|
      assert_nil create_record(record_kind: kind).seen_state_confirmed_at
    end
  end

  test 'explicit seen and unknown states are preserved' do
    assert_equal true, create_record(is_seen: true).effective_state(:is_seen)
    record = create_record(is_seen: nil)
    assert_nil record.seen_state_confirmed_at
    assert_nil record.effective_state(:is_seen)
  end

  test 'an existing confirmation is preserved at creation' do
    confirmed_at = 2.days.ago.change(usec: 0)
    assert_equal confirmed_at, create_record(seen_state_confirmed_at: confirmed_at).seen_state_confirmed_at
  end

  test 'updating a legacy record does not qualify its viewing state' do
    record = create_record
    record.update_columns(is_seen: false, seen_state_confirmed_at: nil)
    record.update!(abstract: 'Résumé enrichi')
    assert_nil record.reload.seen_state_confirmed_at
    assert_nil record.effective_state(:is_seen)
  end

  test 'attaching an export preserves a seen record' do
    record = create_record(is_seen: true)
    VideoAsset.create!(record: record, last_known_path: '/videos/new-export-seen.mkv')
    assert_equal true, record.reload.effective_state(:is_seen)
  end

  test 'attaching an export preserves a legacy unknown record' do
    record = create_record
    record.update_columns(is_seen: false, seen_state_confirmed_at: nil)
    VideoAsset.create!(record: record, last_known_path: '/videos/new-export-unknown.mkv')
    assert_nil record.reload.seen_state_confirmed_at
    assert_nil record.effective_state(:is_seen)
  end

  private

  def create_record(attributes = {})
    attributes[:parent] = parent_for(attributes[:record_kind]) if %w[episode season].include?(attributes[:record_kind])
    Record.create!({ french_title: 'Nouvelle vidéo', record_kind: 'standalone_video',
                     language_version: @language }.merge(attributes))
  end

  def parent_for(kind)
    series = Record.create!(french_title: 'Série', record_kind: 'series', language_version: @language)
    return series if kind == 'season'

    series.children.create!(french_title: 'Saison 01', record_kind: 'season', rank: 1, language_version: @language)
  end
end
