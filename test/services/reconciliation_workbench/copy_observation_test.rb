require 'test_helper'
require 'tmpdir'

class ReconciliationWorkbenchCopyObservationTest < ActiveSupport::TestCase
  setup do
    @directory = Dir.mktmpdir('vidb-copy-preference-', '/tmp')
    @path = File.join(@directory, 'copy.mkv')
    File.write(@path, 'video fixture')
    File.utime(Time.now - 172_800, Time.now - 172_800, @path)
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    record = Record.create!(french_title: 'Fichier comparé', record_kind: 'standalone_video', language_version: language)
    @receipt = { 'format' => 'video_encoder.completed_export', 'version' => 1 }
    @asset = record.video_assets.create!(last_known_path: @path, byte_size: File.size(@path), observed_at: Time.current,
                                        technical_details: { 'video_encoder_export' => @receipt })
    @guard = Object.new
    @guard.define_singleton_method(:call) { true }
    observer = Object.new
    observer.define_singleton_method(:call) { |entry| { path: entry[:path], byte_size: entry[:size], observed_at: Time.current } }
    @service = ReconciliationWorkbench::CopyObservation.new(root: @directory, guard: @guard, observer: observer,
                                                            encoder: ->(_path) { { receipt: @receipt } })
  end

  teardown { FileUtils.remove_entry(@directory) }

  test 'an encoder receipt must exist and match the validated stored receipt' do
    input = @service.inputs([@asset])
    assert_equal false, @service.measure(input).sole['encoder_verified']
    File.write("#{@path}#{VideoAssets::CompletedExport::SUFFIX}", '{}')
    assert_equal true, @service.measure(input).sole['encoder_verified']
    @receipt = { 'other' => 'receipt' }
    assert_equal false, @service.measure(input).sole['encoder_verified']
  end

  test 'measurement time alone does not invalidate the family form' do
    input = @service.inputs([@asset])
    assert_equal @service.measure(input), @service.measure(input)
    assert_not @service.measure(input).sole.fetch('measurement').key?('observed_at')
  end

  test 'file identity changes after planning are detected even with unchanged size' do
    input = @service.inputs([@asset])
    File.write(@path, 'other fixture')
    assert_raises(ArgumentError) { @service.verify!(input) }
  end

  test 'an unstable or unobserved changed copy cannot supply a preference' do
    File.utime(Time.now, Time.now, @path)
    assert_raises(ArgumentError) { @service.inputs([@asset]) }
    File.utime(Time.now - 172_800, Time.now - 172_800, @path)
    @asset.byte_size += 1
    assert_raises(ArgumentError) { @service.inputs([@asset]) }
  end

  test 'a symbolic path is refused' do
    symbolic = File.join(@directory, 'linked.mkv')
    File.symlink(@path, symbolic)
    @asset.last_known_path = symbolic
    assert_raises(ArgumentError) { @service.inputs([@asset]) }
  end

  test 'a missing volume blocks observation' do
    @guard.define_singleton_method(:call) { raise ArgumentError, 'Mount unavailable' }
    assert_raises(ArgumentError) { @service.inputs([@asset]) }
  end
end
