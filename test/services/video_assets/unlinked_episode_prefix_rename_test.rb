require 'test_helper'
require 'tmpdir'

class VideoAssetsUnlinkedEpisodePrefixRenameTest < ActiveSupport::TestCase
  setup do
    @root = Dir.mktmpdir('vidb-prefix-', '/tmp')
    @directory = File.join(@root, 'Code Quantum')
    Dir.mkdir(@directory)
    @source = File.join(@directory, 'Code quantum S03 E04 - La corde raide.avi')
    @target = File.join(@directory, 'S03 E04 - La corde raide.avi')
    @journal = File.join(@root, 'journal', 'code-quantum.jsonl')
    File.write(@source, 'video fixture')
  end

  teardown { FileUtils.remove_entry(@root) }

  def service(adapters = {})
    VideoAssets::UnlinkedEpisodePrefixRename.new(root: @root, directory: @directory,
      series_title: 'Code Quantum', journal_path: @journal, adapters: { guard: -> { true } }.merge(adapters))
  end

  def tracked_copy(path)
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    record = Record.create!(french_title: 'La corde raide', language_version: language)
    record.video_assets.create!(last_known_path: path)
  end

  test 'preview preserves every file and does not create a journal or database rows' do
    result = service.call
    assert_equal 1, result['operations'].size
    assert_equal @target, result['operations'].sole['target']
    assert_not result['execution_authorized']
    assert File.exist?(@source)
    assert_not File.exist?(@target)
    assert_not File.exist?(@journal)
    assert_equal 0, VideoAsset.count
  end

  test 'apply renames without overwriting and a repeated run changes nothing' do
    inode = File.stat(@source).ino
    result = service.call(apply: true)
    assert_equal 1, result['renamed_this_run']
    assert_equal 1, result['total']
    assert_not File.exist?(@source)
    assert_equal inode, File.stat(@target).ino
    assert_equal 'video fixture', File.read(@target)
    assert_equal 0, service.call(apply: true)['renamed_this_run']
    assert_equal 0, VideoAsset.count
  end

  test 'failure after the physical rename resumes by closing the journal without moving again' do
    calls = 0
    renamer = Object.new
    renamer.define_singleton_method(:call) do |**arguments|
      calls += 1
      VideoAssets::RelocationFileRename.new.call(**arguments)
      raise 'Interruption après renommage'
    end
    assert_raises(RuntimeError) { service(renamer: renamer).call(apply: true) }
    assert File.exist?(@target)
    assert_equal 0, service.call(apply: true)['renamed_this_run']
    assert_equal 1, calls
  end

  test 'occupied target is refused before any file is renamed' do
    File.write(@target, 'existing video')
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_equal 'video fixture', File.read(@source)
    assert_equal 'existing video', File.read(@target)
  end

  test 'tracked sources are refused without touching their paths or metadata' do
    asset = tracked_copy(@source)
    before = asset.attributes
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_equal before, asset.reload.attributes
    assert File.exist?(@source)
    assert_not File.exist?(@target)
  end

  test 'a tracked source appearing after preparation blocks the resumed rename' do
    renamer = Object.new
    renamer.define_singleton_method(:call) { |**_arguments| raise 'Interruption avant renommage' }
    assert_raises(RuntimeError) { service(renamer: renamer).call(apply: true) }
    tracked_copy(@source)
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert File.exist?(@source)
  end

  test 'a target imported after interruption does not cause a second physical rename' do
    renamer = Object.new
    renamer.define_singleton_method(:call) do |**arguments|
      VideoAssets::RelocationFileRename.new.call(**arguments)
      raise 'Interruption'
    end
    assert_raises(RuntimeError) { service(renamer: renamer).call(apply: true) }
    asset = tracked_copy(@target)
    assert_equal 0, service.call(apply: true)['renamed_this_run']
    assert_equal @target, asset.reload.last_known_path
  end

  test 'source changes after preparation block a resumed rename' do
    renamer = Object.new
    renamer.define_singleton_method(:call) { |**_arguments| raise 'Interruption' }
    assert_raises(RuntimeError) { service(renamer: renamer).call(apply: true) }
    File.write(@source, 'manual replacement')
    assert_raises(ArgumentError) { service.call(apply: true) }
    assert_not File.exist?(@target)
  end

  test 'companions and ambiguous episode numbering are refused' do
    companion = @source.sub('.avi', '.json')
    File.write(companion, '{}')
    assert_raises(ArgumentError) { service.call }
    File.delete(companion)
    File.rename(@source, @source.sub('E04', 'E04 S03 E05'))
    assert_raises(ArgumentError) { service.call }
  end

  test 'other series and already normalized names remain unchanged' do
    other = File.join(@directory, 'Other Show S03 E04 - La corde raide.avi')
    normalized = File.join(@directory, 'S03 E05 - La suite.mkv')
    File.write(other, 'other video')
    File.write(normalized, 'normalized video')
    assert_equal 1, service.call(apply: true)['total']
    assert_equal 'other video', File.read(other)
    assert_equal 'normalized video', File.read(normalized)
  end

  test 'symbolic sources and a journal from a different series are refused' do
    outside = File.join(@root, 'outside.avi')
    File.rename(@source, outside)
    File.symlink(outside, @source)
    assert_raises(ArgumentError) { service.call }
    File.delete(@source)
    File.rename(outside, @source)
    service.call(apply: true)
    runner = VideoAssets::UnlinkedEpisodePrefixRename.new(root: @root, directory: @directory,
      series_title: 'Another show', journal_path: @journal, adapters: { guard: -> { true } })
    assert_raises(ArgumentError) { runner.call(apply: true) }
  end
end
