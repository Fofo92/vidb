# frozen_string_literal: true

require 'test_helper'

class ConfirmedHierarchyTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @root = Record.create!(french_title: 'Europe', language_version: language, is_checked: false)
    @titles = ['Premier', 'Deuxième']
  end

  test 'preview leaves catalog unchanged' do
    assert_no_difference('Record.count') { assert_equal 'missing', service.call[:previous_status] }
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'creates consistent hierarchy without video assets or inferred viewing states' do
    assert_no_difference('VideoAsset.count') { assert_difference('Record.count', 3) { service.call(apply: true) } }
    season = @root.reload.children.sole
    assert_equal 'series', @root.record_kind
    assert_equal 'season', season.record_kind
    assert_equal 1, season.rank
    assert_equal @titles, season.children.order(:rank).pluck(:french_title)
    season.children.each do |episode|
      assert_equal :consistent, episode.hierarchy_placement_status
      assert_nil episode.is_available
      assert_nil episode.is_recorded
      assert_nil episode.is_seen
      assert_equal false, episode.is_checked
    end
    assert_equal false, @root.is_checked
  end

  test 'rerun does not create duplicates' do
    service.call(apply: true)
    assert_no_difference('Record.count') do
      assert_equal 'already_present', service.call(apply: true)[:previous_status]
    end
  end

  test 'existing children block apply and root qualification' do
    @root.children.create!(french_title: 'Historique', language_version: @root.language_version)
    assert_no_difference('Record.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'title changes block apply' do
    @root.update!(french_title: 'Autre')
    assert_no_difference('Record.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
  end

  test 'standalone records cannot be requalified automatically' do
    @root.update!(record_kind: 'standalone_video')
    assert_no_difference('Record.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_equal 'standalone_video', @root.reload.record_kind
  end

  test 'rerun preserves editorial and viewing states' do
    service.call(apply: true)
    episode = @root.children.sole.children.order(:rank).first
    episode.update!(is_seen: true, is_checked: true)
    service.call(apply: true)
    assert_equal true, episode.reload.is_seen
    assert_equal true, episode.is_checked
  end

  test 'changed episode titles prevent a rerun from overwriting them' do
    service.call(apply: true)
    episode = @root.children.sole.children.order(:rank).first
    episode.update!(french_title: 'Titre modifié')
    assert_no_difference('Record.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_equal 'Titre modifié', episode.reload.french_title
  end

  test 'late validation failure rolls back the complete hierarchy' do
    validation = -> { errors.add(:base, 'rejected for rollback test') if french_title == 'Deuxième' }
    Record.validate validation
    assert_no_difference('Record.count') do
      assert_raises(ActiveRecord::RecordInvalid) { service.call(apply: true) }
    end
    assert_equal 'undetermined', @root.reload.record_kind
  ensure
    Record.skip_callback(:validate, :before, validation) if validation
  end

  private

  def service
    CatalogEnrichment::ConfirmedHierarchy.new(record_id: @root.id, series_title: 'Europe', episode_titles: @titles)
  end
end
