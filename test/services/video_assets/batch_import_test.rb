# frozen_string_literal: true

require 'test_helper'

class BatchImportTest < ActiveSupport::TestCase
  class Observer
    attr_accessor :fail_verification, :volume

    def initialize
      @volume = 'test-volume'
    end

    def call(entry)
      { path: entry.fetch(:path), byte_size: entry.fetch(:size), duration_minutes: 52,
        measured_duration_seconds: 3131.008, container: 'mp4', observed_at: Time.current,
        technical_details: { 'storage' => { 'uuid' => volume },
                             'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'und' } }] } }
    end

    def verify!(_observed)
      raise ArgumentError, 'File changed before import' if fail_verification
    end
  end

  setup do
    @language = LanguageVersion.create!(short_name: 'BATCH', long_name: 'Version historique test')
    @medium = Medium.create!(short_name: 'BATCH', long_name: 'Disque test')
    @records = [1, 2].map do |number|
      Record.create!(french_title: "Batch unique #{number}", language_version: @language,
                     record_kind: 'standalone_video', is_seen: true, is_checked: false)
    end
    @evidence = {
      format: 'vidb.video_asset_import_batch', version: 1, medium: 'BATCH', storage_uuid: 'test-volume',
      source_inventory: { format: 'vidb.video_library_inventory', version: 1,
                          generated_at: Time.current.iso8601, roots: ['/videos'] },
      selection_policy: { name: 'strict_qualified_unique_title_match' }, entries: @records.map { |record| entry(record) }
    }
    @observer = Observer.new
    @initial_states = @records.map { |record| record.attributes.slice('is_available', 'is_recorded') }
  end

  test 'preview creates no assets and changes no states' do
    assert_no_difference('VideoAsset.count') do
      report = service.call
      assert_equal false, report[:applied]
      assert_equal 2, report[:total]
    end
    assert_equal @initial_states.first, @records.first.reload.attributes.slice('is_available', 'is_recorded')
  end

  test 'import measures copies and preserves editorial and language distinctions' do
    assert_difference('VideoAsset.count', 2) { service.call(apply: true) }
    asset = @records.first.video_assets.sole
    assert_equal @medium.id, asset.medium_id
    assert_nil asset.language_version_id
    assert_equal 'und', asset.technical_details.dig('streams', 0, 'tags', 'language')
    record = @records.first.reload
    assert_equal true, record.is_available
    assert_equal true, record.is_recorded
    assert_equal true, record.is_seen
    assert_equal false, record.is_checked
    assert_empty record.media
    assert_equal @language.id, record.language_version_id
  end

  test 'rerun refreshes existing copies without losing confirmed language or provenance' do
    service.call(apply: true)
    asset = @records.first.video_assets.sole
    asset.update!(language_version: @language, technical_details: asset.technical_details.merge('confirmation' => 'manual'))
    assert_no_difference('VideoAsset.count') { service.call(apply: true) }
    assert_equal @language.id, asset.reload.language_version_id
    assert_equal 'manual', asset.technical_details['confirmation']
  end

  test 'changed title blocks the complete batch' do
    @records.last.update!(french_title: 'Titre modifié')
    assert_rejected
  end

  test 'episode context and numbering are checked before importing' do
    episode = prepare_episode
    assert_difference('VideoAsset.count', 1) { service.call(apply: true) }
    assert_equal 52, episode.video_assets.sole.duration_minutes
    assert_nil episode.video_assets.sole.language_version_id
  end

  test 'a changed series context blocks an episode import' do
    episode = prepare_episode
    episode.root.update!(french_title: 'Série renommée')
    assert_rejected
  end

  test 'a new homonym prevents accepting an obsolete unique match' do
    Record.create!(french_title: @records.last.french_title, language_version: @language)
    assert_rejected
  end

  test 'another present copy of the same record blocks the batch' do
    VideoAsset.create!(record: @records.last, last_known_path: '/videos/another.mkv')
    assert_rejected
  end

  test 'a path already assigned to another work is preserved' do
    other = Record.create!(french_title: 'Autre œuvre', language_version: @language)
    VideoAsset.create!(record: other, last_known_path: @evidence[:entries].last[:path])
    assert_rejected
  end

  test 'unexpected storage blocks the batch' do
    @observer.volume = 'other-volume'
    assert_rejected
  end

  test 'a file changed after measurement blocks all writes' do
    @observer.fail_verification = true
    assert_rejected
  end

  test 'recent files cannot be smuggled into the manifest' do
    @evidence[:entries].last[:modified_at] = Time.current.iso8601
    assert_rejected
  end

  test 'late asset validation failure rolls back earlier assets and states' do
    failing_path = @evidence[:entries].last[:path]
    validation = -> { errors.add(:base, 'test failure') if last_known_path == failing_path }
    VideoAsset.validate validation
    assert_no_difference('VideoAsset.count') do
      assert_raises(ActiveRecord::RecordInvalid) { service.call(apply: true) }
    end
    assert_equal @initial_states.first, @records.first.reload.attributes.slice('is_available', 'is_recorded')
  ensure
    VideoAsset.skip_callback(:validate, :before, validation) if validation
  end

  private

  def prepare_episode
    root = Record.create!(french_title: 'Série batch', language_version: @language, record_kind: 'series')
    season = root.children.create!(french_title: 'Saison 01', rank: 1,
                                   language_version: @language, record_kind: 'season')
    episode = season.children.create!(french_title: 'Premier', rank: 1,
                                      language_version: @language, record_kind: 'episode')
    observed = { path: '/videos/Série batch/Saison 01/S01 E01 - Premier.mkv',
                 relative_path: 'Série batch/Saison 01/S01 E01 - Premier.mkv', stem: 'S01 E01 - Premier',
                 type: 'file', extension: '.mkv', size: 1234, modified_at: 2.days.ago.iso8601 }
    matched = VideoAssets::EpisodeMatcher.new(Record.all).match(observed)
    @evidence[:entries] = [observed.merge(status: matched[:status], title_evidence: matched[:title_evidence],
                                        candidate: matched.fetch(:candidates).sole)]
    episode
  end

  def entry(record)
    { path: "/videos/#{record.french_title}.mkv", relative_path: "#{record.french_title}.mkv",
      type: 'file', extension: '.mkv', stem: record.french_title, size: 1234,
      modified_at: 2.days.ago.iso8601, status: 'exact',
      candidate: VideoAssets::TitleMatcher.new([record]).match(record.french_title).fetch(:candidates).sole }
  end

  def service
    VideoAssets::BatchImport.new(evidence: @evidence, observer: @observer)
  end

  def assert_rejected
    assert_no_difference('VideoAsset.count') { assert_raises(ArgumentError) { service.call(apply: true) } }
    assert_empty @records.first.video_assets
  end
end
