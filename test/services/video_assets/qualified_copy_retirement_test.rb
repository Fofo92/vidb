require 'test_helper'

module VideoAssets
  class QualifiedCopyRetirementTest < ActiveSupport::TestCase
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
