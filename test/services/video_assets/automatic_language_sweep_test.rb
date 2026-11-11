require 'test_helper'
require 'tmpdir'

class AutomaticLanguageSweepTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    record = Record.create!(french_title: 'Ancienne copie', language_version: language)
    @copies = 3.times.map { |number| record.video_assets.create!(last_known_path: "/videos/legacy-#{number}.mkv") }
  end

  test 'unresolved copies and failures do not starve later copies and are retried' do
    calls = []
    qualifier = lambda do |asset_id:, apply:|
      assert apply
      calls << asset_id
      raise ArgumentError, 'Copie indisponible' if asset_id == @copies.first.id

      { status: 'needs_review', applied: false }
    end
    Dir.mktmpdir do |directory|
      sweep = VideoAssets::AutomaticLanguageSweep.new(directory: directory, qualifier: qualifier, limit: 1)
      4.times { sweep.call }
      assert_equal @copies.map(&:id) + [@copies.first.id], calls
      report = JSON.parse(File.read(File.join(directory, 'automatic-languages.json')))
      assert_equal 'error', report['copies'].first['status']
    end
  end

  test 'qualified missing and deleted copies are excluded' do
    @copies.first.update!(language_version_id: @copies.first.record.language_version_id)
    @copies.second.update!(status: 'missing')
    @copies.third.update!(status: 'deleted')
    Dir.mktmpdir do |directory|
      sweep = VideoAssets::AutomaticLanguageSweep.new(directory: directory, qualifier: ->(**) { flunk })
      assert_equal 0, sweep.call[:processed]
    end
  end

  test 'recent imports get priority while older unresolved copies keep advancing' do
    @copies.first(2).each { |copy| copy.update_columns(created_at: 2.days.ago) }
    calls = []
    qualifier = ->(asset_id:, apply:) { calls << asset_id; { status: 'needs_review', applied: apply } }
    Dir.mktmpdir do |directory|
      sweep = VideoAssets::AutomaticLanguageSweep.new(directory: directory, qualifier: qualifier, limit: 2)
      2.times { sweep.call }
      assert_equal [@copies.third.id, @copies.first.id, @copies.third.id, @copies.second.id], calls
    end
  end

  test 'a damaged cursor is visible rather than silently skipping work' do
    Dir.mktmpdir do |directory|
      File.write(File.join(directory, 'language-qualification.cursor'), 'invalid')
      sweep = VideoAssets::AutomaticLanguageSweep.new(directory: directory, qualifier: ->(**) { flunk })
      assert_raises(ArgumentError) { sweep.call }
    end
  end
end
