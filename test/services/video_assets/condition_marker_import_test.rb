require 'test_helper'

module VideoAssets
  class ConditionMarkerImportTest < ActiveSupport::TestCase
    setup do
      language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
      @record = Record.create!(french_title: 'Film', record_kind: 'standalone_video', language_version: language)
      @asset = @record.video_assets.create!(last_known_path: "/videos/Film (fin 41').mkv")
      @asset.update_columns(condition_details: {})
    end

    test 'preview reads filename without requiring any file and performs no writes' do
      before = @asset.reload.attributes
      result = ConditionMarkerImport.new.call
      assert_equal 'proposed', result[:copies].find { |row| row[:video_asset_id] == @asset.id }[:status]
      assert_equal before, @asset.reload.attributes
    end

    test 'apply is idempotent preserves source evidence and updates neither paths nor owner flags' do
      before = @record.reload.attributes
      path = @asset.last_known_path
      ConditionMarkerImport.new.call(apply: true)
      details = @asset.reload.condition_details.deep_dup
      assert_equal 'end', details['retained_portion']
      assert_equal 2460, details['retained_duration_seconds']
      assert details['evidence'].first['imported_at']
      ConditionMarkerImport.new.call(apply: true)
      assert_equal details, @asset.reload.condition_details
      assert_equal path, @asset.last_known_path
      assert_equal before, @record.reload.attributes
    end

    test 'existing manual state is protected and ambiguous legacy markers are not imported' do
      @asset.update!(condition_details: { 'integrality' => 'complete', 'damage' => 'none' })
      other = @record.video_assets.create!(last_known_path: '/videos/Film (début 41).mkv')
      other.update_columns(condition_details: {})
      result = ConditionMarkerImport.new.call(apply: true)
      assert_equal 'preserved', result[:copies].find { |row| row[:video_asset_id] == @asset.id }[:status]
      assert_equal 'needs_review', result[:copies].find { |row| row[:video_asset_id] == other.id }[:status]
      assert_equal({}, other.reload.condition_details)
      assert other.content_incomplete?
    end
  end
end
