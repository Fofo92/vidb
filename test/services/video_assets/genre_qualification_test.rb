# frozen_string_literal: true

require 'test_helper'

class GenreQualificationTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @record = Record.create!(french_title: '355', original_title: 'The 355', year: 2022,
                             record_kind: 'standalone_video', language_version: language)
    @before = %w[Action Aventure Thriller]
    @original_genres = @before.map { |name| Gender.find_or_create_by!(name: name) }
    @record.genders = @original_genres
  end

  test 'replaces the three old genres with Espionnage' do
    result = qualify
    assert_equal true, result[:changed]
    assert_equal ['Espionnage'], @record.genders.reload.pluck(:name)
    assert_equal @before.sort, result[:before]
    assert_equal ['Espionnage'], result[:after]
    assert_equal @original_genres.size, Gender.where(id: @original_genres.map(&:id)).count
  end

  test 'does not change the record again when its genres already match' do
    qualify
    before = @record.reload.attributes
    assert_equal false, qualify[:changed]
    assert_equal before, @record.reload.attributes
  end

  test 'refuses a stale classification without overwriting it' do
    @record.genders = [@original_genres.first]
    assert_raises(VideoAssets::GenreQualification::Refused) { qualify }
    assert_equal ['Action'], @record.genders.reload.pluck(:name)
  end

  test 'refuses more than two desired genres' do
    assert_raises(VideoAssets::GenreQualification::Refused) { qualify(names: @before) }
    assert_equal @before.sort, @record.genders.reload.pluck(:name).sort
  end

  test 'accepts two genres' do
    qualify(names: %w[Espionnage Thriller])
    assert_equal %w[Espionnage Thriller], @record.genders.reload.pluck(:name).sort
  end

  test 'rejects an empty classification' do
    assert_raises(VideoAssets::GenreQualification::Refused) { qualify(names: []) }
  end

  test 'rejects duplicate and unsafe names' do
    assert_raises(VideoAssets::GenreQualification::Refused) { qualify(names: %w[Espionnage Espionnage]) }
    assert_raises(VideoAssets::GenreQualification::Refused) { qualify(names: ['../Espionnage']) }
    assert_equal @before.sort, @record.genders.reload.pluck(:name).sort
  end

  test 'leaves film metadata and copy paths unchanged' do
    asset = VideoAsset.create!(record: @record, last_known_path: '/videos/Films/Espionnage/355 (The 355)_vf.mkv')
    record_before = @record.reload.attributes.except('updated_at')
    copy_before = asset.reload.attributes
    qualify
    assert_equal record_before, @record.reload.attributes.except('updated_at')
    assert_equal copy_before, asset.reload.attributes
  end

  test 'refuses an undetermined record kind' do
    @record.update!(record_kind: 'undetermined')
    assert_raises(VideoAssets::GenreQualification::Refused) { qualify }
    assert_equal @before.sort, @record.genders.reload.pluck(:name).sort
  end

  test 'rolls back association changes when the owner update fails' do
    @record.define_singleton_method(:touch) { raise ActiveRecord::RecordInvalid.new(self) }
    assert_raises(ActiveRecord::RecordInvalid) { qualify }
    assert_equal @before.sort, @record.genders.reload.pluck(:name).sort
  end

  private

  def qualify(names: ['Espionnage'])
    VideoAssets::GenreQualification.new.call(record: @record, names: names, expected_names: @before)
  end
end
