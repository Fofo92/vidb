# frozen_string_literal: true

require 'test_helper'

class BroadcastPartImportTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IN', long_name: 'Indéterminée')
    Medium.find_or_create_by!(short_name: 'HD') { |medium| medium.long_name = 'Disque dur' }
    @root = Record.create!(french_title: 'Test', language_version: language)
    season = @root.children.create!(french_title: 'Saison 1', rank: 1, language_version: language)
    @episode = season.children.create!(french_title: 'Ancien titre', original_title: 'Senza occhi', rank: 1,
                                      language_version: language, is_seen: true, is_checked: true, length_in_mn: 90)
    @evidence = evidence
    @observer = Object.new
    @observer.define_singleton_method(:call) do |entry|
      { path: entry[:path], byte_size: entry[:size], duration_minutes: 40, measured_duration_seconds: 2400.0,
        container: 'matroska', observed_at: Time.current, technical_details: { 'storage' => { 'uuid' => 'disk' } } }
    end
    @observer.define_singleton_method(:verify!) { |_observation| true }
  end

  test 'preview creates no copies and does not correct titles or change states' do
    before = @episode.attributes
    assert_no_difference ['VideoAsset.count', 'Record.count'] do
      assert_not service.call[:applied]
    end
    assert_equal before, @episode.reload.attributes
  end

  test 'apply imports two parts corrects confirmed titles and preserves personal data' do
    assert_difference('VideoAsset.count', 2) { assert service.call(apply: true)[:applied] }
    assert_equal 'Sans les yeux', @episode.reload.french_title
    assert_equal 2, @episode.broadcast_part_count
    assert @episode.is_available
    assert @episode.is_recorded
    assert @episode.is_seen
    assert @episode.is_checked
    assert_equal 90, @episode.length_in_mn
    assert @root.reload.record_kind_series?
    assert @episode.parent.record_kind_season?
    assert_equal [1, 2], @episode.video_assets.order(:broadcast_part_number).pluck(:broadcast_part_number)
    assert @episode.video_assets.all? { |asset| asset.language_version_id.nil? }
    assert_no_difference('VideoAsset.count') { service.call(apply: true) }
  end

  test 'changed catalogue or duplicate file paths block the batch' do
    @episode.update!(french_title: 'Correction indépendante')
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_equal 0, @episode.video_assets.count
  end

  test 'final file change blocks import without changing catalogue' do
    @observer.define_singleton_method(:verify!) { |_observation| raise ArgumentError, 'Changed file' }
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_equal 'Ancien titre', @episode.reload.french_title
    assert_equal 1, @episode.broadcast_part_count
    assert_empty @episode.video_assets
  end

  test 'late copy conflict rolls back titles part declarations and previous copies' do
    second_path = @evidence[:pairs].first[:parts].last[:path]
    foreign = Record.create!(french_title: 'Autre œuvre', language_version: @episode.language_version)
    foreign.video_assets.create!(last_known_path: second_path)
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_equal 'Ancien titre', @episode.reload.french_title
    assert_equal 1, @episode.broadcast_part_count
    assert_empty @episode.video_assets
  end

  test 'unexpected failure during second save rolls back the first copy and corrected titles' do
    second_path = @evidence[:pairs].first[:parts].last[:path]
    callback = lambda do |asset|
      raise 'Late save failure' if asset.last_known_path == second_path
    end
    VideoAsset.set_callback(:create, :after, callback)
    assert_no_difference('VideoAsset.count') do
      assert_raises(RuntimeError) { service.call(apply: true) }
    end
    assert_equal 'Ancien titre', @episode.reload.french_title
    assert_equal 1, @episode.broadcast_part_count
    assert_not @episode.is_available
  ensure
    VideoAsset.skip_callback(:create, :after, callback) if callback
  end

  private

  def service
    CatalogEnrichment::BroadcastPartImport.new(evidence: @evidence, observer: @observer)
  end

  def evidence
    parts = (1..2).map do |number|
      { part: number, size: 100, modified_at: 3.days.ago.iso8601,
        path: "/videos/Test/Saison 01/S01 E0#{number} - Sans les yeux, partie #{number} (Senza occhi).mkv" }
    end
    { format: 'vidb.broadcast_part_import', version: 1, root_record_id: @root.id, directory: '/videos/Test',
      storage_uuid: 'disk', confirmed_basis: 'Confirmed test',
      pairs: [{ record_id: @episode.id, season: 1, episode: 1, parts: parts,
                expected_titles: { french_title: 'Ancien titre', original_title: 'Senza occhi' },
                corrections: { french_title: 'Sans les yeux' } }] }
  end
end
