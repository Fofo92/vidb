# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'

class ConfirmedSeriesLanguagePlanTest < ActiveSupport::TestCase
  test 'rejects a confirmation outside the authorized series' do
    evidence = { format: 'vidb.broadcast_part_import', version: 1, root_record_id: 123, pairs: [] }
    assert_raises(ArgumentError) do
      VideoAssets::ConfirmedSeriesLanguagePlan.new(import_evidence: evidence).call
    end
  end

  test 'plans the imported copies without changing catalogue or language qualifications' do
    Dir.mktmpdir do |directory|
      evidence = prepare_evidence(directory)
      before = VideoAsset.where(record_id: evidence[:pairs].pluck(:record_id)).pluck(:id, :language_version_id)
      plan = VideoAssets::ConfirmedSeriesLanguagePlan.new(import_evidence: evidence, observer: observer)
      assert_no_difference ['Record.count', 'VideoAsset.count'] do
        report = plan.call
        assert_equal({ 'candidate' => 36 }, report[:counts])
        assert_equal 36, report[:manifest][:copies].size
        assert report[:manifest][:copies].all? { |copy| copy['language_version'] == 'VF' }
      end
      after = VideoAsset.where(record_id: evidence[:pairs].pluck(:record_id)).pluck(:id, :language_version_id)
      assert_equal before, after
      VideoAsset.find(before.first.first).update!(status: 'deleted')
      assert_raises(ActiveRecord::RecordNotFound) { plan.call }
    end
  end

  private

  def prepare_evidence(directory)
    language = LanguageVersion.create!(short_name: 'IN', long_name: 'Indéterminée')
    root = Record.create!(id: 3442, french_title: 'Blanca test', record_kind: 'series', language_version: language)
    season = root.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season', language_version: language)
    pairs = (1..18).map do |rank|
      record = season.children.create!(french_title: "Épisode #{rank}", record_kind: 'episode', rank: rank,
                                       language_version: language, broadcast_part_count: 2)
      parts = (1..2).map { |number| prepare_copy(directory, record, number) }
      { record_id: record.id, parts: parts }
    end
    { format: 'vidb.broadcast_part_import', version: 1, root_record_id: root.id, pairs: pairs, storage_uuid: 'disk' }
  end

  def prepare_copy(directory, record, number)
    path = File.join(directory, "#{record.id}-part-#{number}.mkv")
    File.write(path, 'video')
    timestamp = 10.days.ago.to_time
    File.utime(timestamp, timestamp, path)
    record.video_assets.create!(status: 'present', last_known_path: path, broadcast_part_number: number,
                                byte_size: 5, observed_at: 3.days.ago)
    { part: number, path: path, size: 5 }
  end

  def observer
    Object.new.tap do |object|
      object.define_singleton_method(:call) do |path|
        { path: path, byte_size: 5,
          technical_details: { 'storage' => { 'uuid' => 'disk' },
                               'streams' => [{ 'codec_type' => 'audio', 'tags' => { 'language' => 'und' } }] } }
      end
    end
  end
end
