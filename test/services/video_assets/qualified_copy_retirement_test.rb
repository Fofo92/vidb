require 'test_helper'

module VideoAssets
  class QualifiedCopyRetirementTest < ActiveSupport::TestCase
    test 'a pure default presumption does not disable existing redundant reference detection' do
      language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
      record = Record.create!(french_title: 'Film', record_kind: 'standalone_video', language_version: language)
      old = record.video_assets.create!(last_known_path: '/videos/ancien/Film.mkv', status: 'missing')
      replacement = record.video_assets.create!(last_known_path: '/videos/nouveau/Film.mkv')
      assert_not old.condition_information_protected?
      retirement = RedundantCopyRetirement.new(root: '/videos', backup: Object.new)
      retirement.define_singleton_method(:safely_absent?) { |_path| true }
      key = retirement.send(:copy_key, old)
      assert_equal replacement, retirement.send(:replacement_for, old, {}, { key => replacement })
      old.update_columns(condition_details: { 'integrality' => 'complete', 'damage' => 'none' })
      assert old.reload.condition_information_protected?
      assert_nil retirement.send(:replacement_for, old, {}, { key => replacement })
    end

    test 'automatic cleanup retains qualified references rather than discarding their condition history' do
      language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
      record = Record.create!(french_title: 'Film', record_kind: 'standalone_video', language_version: language)
      old = record.video_assets.create!(last_known_path: '/videos/ancien/Film.mkv', status: 'missing',
                                       condition_details: { 'integrality' => 'incomplete', 'damage' => 'light' })
      replacement = record.video_assets.create!(last_known_path: '/videos/nouveau/Film.mkv')
      backup = Object.new
      backup.define_singleton_method(:write) { |*_args, **_options| raise 'No reference should be retired' }
      result = RedundantCopyRetirement.new(root: '/videos', backup: backup).call([replacement], [old]) { true }
      assert_equal 0, result
      assert VideoAsset.exists?(old.id)
      assert_equal 'incomplete', old.reload.condition_details['integrality']
    end
  end
end
