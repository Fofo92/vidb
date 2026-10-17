require 'test_helper'
require 'minitest/mock'

class ReconciliationWorkbenchCandidateCopyTest < ActiveSupport::TestCase
  class Observer
    attr_accessor :fail_verification
    attr_reader :measurements

    def initialize
      @measurements = {}
    end

    def inputs(assets)
      assets.map do |asset|
        { 'asset_id' => asset.id, 'path' => asset.last_known_path, 'identity' => { 'size' => asset.byte_size },
          'snapshot' => ReconciliationWorkbench::Snapshot.asset(asset) }
      end
    end

    def measure(inputs)
      inputs.map { |input| input.merge(measurements.fetch(input.fetch('path'))) }
    end

    def verify!(_samples)
      raise 'Disque modifié' if fail_verification
    end
  end

  setup do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    Medium.create!(short_name: 'HD', long_name: 'Disque dur')
    @record = Record.create!(french_title: 'Film comparé', record_kind: 'standalone_video', language_version: language)
    @path = '/videos/Film comparé.mkv'
    @asset = @record.video_assets.create!(last_known_path: '/videos/ancienne.mkv', byte_size: 1000, observed_at: Time.current)
    source = { format: 'vidb.video_library_inventory', version: 1, generated_at: Time.current.iso8601, roots: ['/videos'] }
    entry = { path: @path, type: 'file', extension: '.mkv', stem: @record.french_title,
              size: 800, modified_at: 2.days.ago.iso8601 }
    match = VideoAssets::ReconciliationReport.new(inventory: source.merge(entries: [entry])).call[:observations].sole
    @payload = { 'record_id' => @record.id, 'path' => @path, 'identity' => { 'size' => 800 },
                 'source_inventory' => source.as_json, 'entry' => match.merge(type: 'file', candidate: match[:candidates].sole).as_json }
    @observer = Observer.new
    @observer.measurements[@asset.last_known_path] = measurement(1000, false)
    @observer.measurements[@path] = measurement(800, true)
    @action = ReconciliationWorkbench::CopyPreferenceAction.new(observer: @observer)
  end

  def measurement(bytes, richer)
    video = { 'codec_type' => 'video', 'width' => 1920, 'height' => 1080 }
    french = { 'codec_type' => 'audio', 'channels' => 2, 'tags' => { 'language' => 'fra' } }
    streams = [video, french]
    streams << french.deep_dup.tap { |track| track['tags']['language'] = 'eng' } if richer
    { 'modified_at' => (richer ? 2.days.ago : 3.years.ago).iso8601,
      'encoder_verified' => richer, 'encoder_receipt' => richer ? { 'test' => 'receipt' } : nil,
      'measurement' => { 'path' => richer ? @path : @asset.last_known_path, 'byte_size' => bytes,
                         'duration_minutes' => 22, 'measured_duration_seconds' => 1320, 'container' => 'mkv',
                         'technical_details' => { 'streams' => streams, 'storage' => { 'uuid' => VideoAssets::ReconciliationVolumeGuard::UUID } } } }
  end

  def propose
    File.stub(:mtime, 2.days.ago.to_time) do
      ReconciliationWorkbench::CopyPreferencePlan.new(observer: @observer).call(candidates: { @record.id => @payload })
    end
    @item = ReconciliationCase.current.sole
    ReconciliationRuleDecision.create!(rule_key: @item.rule_key, rule_version: @item.rule_version, decision: 'approved')
  end

  def apply
    File.stub(:mtime, 2.days.ago.to_time) do
      VideoAssets::BatchFileObservation.stub(:new, @observer) do
        ReconciliationWorkbench::Executor.new(preference: @action).call(@item)
      end
    end
  end

  test 'candidate registration and preference commit once in the same transaction' do
    propose
    assert_equal true, @item.payload.dig('comparison', 'eligible')
    assert_equal 'applied', apply
    created = VideoAsset.find_by!(last_known_path: @path)
    assert_equal true, created.technical_details.dig('copy_preference', 'preferred')
    assert_equal false, @asset.reload.technical_details.dig('copy_preference', 'preferred')
    assert_equal 2, @record.video_assets.count
    assert_equal 'skipped', apply
    assert_equal 2, @record.video_assets.count
    ReconciliationWorkbench::CopyPreferencePlan.new(observer: @observer).call
    assert_equal 0, ReconciliationCase.current.count
  end

  test 'failed final verification rolls back the import and preference before retry' do
    propose
    @observer.fail_verification = true
    assert_equal 'blocked', apply
    assert_equal 1, @record.video_assets.count
    assert_nil @asset.reload.technical_details['copy_preference']
    @observer.fail_verification = false
    assert_equal 'applied', apply
    assert_equal 2, @record.video_assets.count
  end

  test 'another registered copy blocks the old proposal without registering the candidate' do
    propose
    @record.video_assets.create!(last_known_path: '/videos/troisieme.mkv')
    assert_equal 'blocked', apply
    assert_nil VideoAsset.find_by(last_known_path: @path)
  end

  test 'the existing copy may win over an older candidate' do
    @asset.update!(byte_size: 800)
    @payload['entry']['size'] = 1000
    old = measurement(1000, false)
    old['measurement']['path'] = @path
    recent = measurement(800, true)
    recent['measurement']['path'] = @asset.last_known_path
    @observer.measurements[@path] = old
    @observer.measurements[@asset.last_known_path] = recent
    propose
    assert_equal @asset.id, @item.payload.dig('comparison', 'preferred_asset_id')
    assert_equal 'applied', apply
    assert_equal true, @asset.reload.technical_details.dig('copy_preference', 'preferred')
    assert_equal 2, @record.video_assets.count
  end
end
