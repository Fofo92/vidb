require 'test_helper'

module VideoAssets
  class ConditionUpdateTest < ActiveSupport::TestCase
    setup do
      language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
      @record = Record.create!(french_title: 'Film', record_kind: 'standalone_video', language_version: language)
      @asset = @record.video_assets.create!(last_known_path: '/videos/Film (d).mkv')
      @user = Struct.new(:id).new(12)
    end

    def update(values, fingerprint = ConditionUpdate.fingerprint(@asset.reload))
      ConditionUpdate.new(@asset, attributes: values, fingerprint: fingerprint, user: @user).call
    end

    test 'manual qualification records user history preserves legacy evidence and never changes owner path or states' do
      path = @asset.last_known_path
      before = @record.reload.attributes
      update('integrality' => 'incomplete', 'damage' => 'light', 'retained_portion' => 'end',
             'retained_duration_minutes' => '41', 'note' => 'Début manquant')
      details = @asset.reload.condition_details
      assert_equal 2460, details['retained_duration_seconds']
      assert_equal 'end', details['retained_portion']
      assert_equal 'legacy_filename_v1', details['evidence'].first['origin']
      assert_equal 12, details['evidence'].last['user_id']
      assert_equal path, @asset.last_known_path
      assert_equal before, @record.reload.attributes
    end

    test 'stale changes are refused instead of overwriting another qualification' do
      fingerprint = ConditionUpdate.fingerprint(@asset)
      @asset.update!(duration_minutes: 42)
      assert_raises(ConditionUpdate::Stale) { update({ 'integrality' => 'complete' }, fingerprint) }
      assert_equal 'unknown', @asset.reload.condition_details['integrality']
    end

    test 'contradictory or fractional duration is rejected without persisting history' do
      before = @asset.reload.condition_details.deep_dup
      assert_raises(ArgumentError) do
        update('integrality' => 'incomplete', 'retained_duration_minutes' => '41.5')
      end
      assert_equal before, @asset.reload.condition_details
      assert_raises(ActiveRecord::RecordInvalid) do
        update('integrality' => 'complete', 'retained_duration_minutes' => '41')
      end
      assert_equal before, @asset.reload.condition_details
    end
  end
end
