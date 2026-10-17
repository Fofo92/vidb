require 'test_helper'
require 'minitest/mock'

class ReconciliationWorkbenchCopyPreferenceTest < ActiveSupport::TestCase
  class Observer
    attr_accessor :fail_verification

    def inputs(assets)
      assets.map do |asset|
        { 'asset_id' => asset.id, 'path' => asset.last_known_path, 'snapshot' => ReconciliationWorkbench::Snapshot.asset(asset),
          'identity' => { 'ino' => asset.id, 'size' => asset.byte_size } }
      end
    end

    def measure(inputs)
      inputs.map do |input|
        asset = VideoAsset.find(input['asset_id'])
        input.merge('modified_at' => asset.technical_details.fetch('test_modified_at'),
          'encoder_verified' => asset.technical_details['test_encoder'] == true,
          'measurement' => { 'byte_size' => asset.byte_size, 'measured_duration_seconds' => 1320,
                            'technical_details' => asset.technical_details.slice('streams') })
      end
    end

    def verify!(_samples)
      raise 'File changed' if fail_verification
    end
  end

  setup do
    language = LanguageVersion.create!(short_name: 'VM', long_name: 'Multilingue')
    @record = Record.create!(french_title: 'Copie comparée', record_kind: 'standalone_video', language_version: language)
    video = { 'codec_type' => 'video', 'width' => 1920, 'height' => 1080 }
    french = { 'codec_type' => 'audio', 'channels' => 2, 'tags' => { 'language' => 'fra' } }
    english = french.deep_dup.tap { |stream| stream['tags']['language'] = 'eng' }
    @old = @record.video_assets.create!(last_known_path: '/videos/ancienne.mkv', byte_size: 1000,
      technical_details: { 'test_modified_at' => '2021-01-01T00:00:00Z', 'streams' => [video, french] })
    @new = @record.video_assets.create!(last_known_path: '/videos/nouvelle.mkv', byte_size: 800,
      technical_details: { 'test_modified_at' => '2026-10-01T00:00:00Z', 'test_encoder' => true,
                           'streams' => [video, french, english] })
    @observer = Observer.new
    @planner = ReconciliationWorkbench::CopyPreferencePlan.new(observer: @observer)
    @action = ReconciliationWorkbench::CopyPreferenceAction.new(observer: @observer)
    @planner.call
    @item = ReconciliationCase.current.sole
  end

  def approve
    ReconciliationRuleDecision.create!(rule_key: @item.rule_key, rule_version: @item.rule_version, decision: 'approved')
  end

  def apply
    ReconciliationWorkbench::Executor.new(preference: @action).call(@item)
  end

  test 'new family is independent and requires its own decision' do
    assert_equal 'skipped', apply
    assert_nil @new.reload.technical_details['copy_preference']
    ReconciliationRuleDecision.create!(rule_key: ReconciliationWorkbench::Rules::DISK.key, rule_version: 1, decision: 'approved')
    assert_equal 'skipped', apply
  end

  test 'selects one provisional preference and retains both physical copy records without reimport' do
    approve
    before = [@old, @new].map { |asset| asset.attributes.except('technical_details', 'updated_at') }
    assert_equal 'applied', apply
    assert_equal [false, true], [@old, @new].map { |asset| asset.reload.technical_details.dig('copy_preference', 'preferred') }
    assert_equal before, [@old, @new].map { |asset| asset.attributes.except('technical_details', 'updated_at') }
    assert_equal 2, @record.video_assets.where(status: 'present').count
    assert_equal false, @item.reload.result['quality_assessed']
    assert_equal 'skipped', apply
    @planner.call
    assert_equal 1, ReconciliationCase.count
    assert_equal 0, ReconciliationCase.current.count
  end

  test 'manual metadata edits on a copy block the old comparison even after replanning' do
    approve
    @old.update!(container: 'Correction manuelle')
    @planner.call
    assert_equal @item.id, ReconciliationCase.current.sole.id
    assert_equal 'blocked', apply
    assert_nil @new.reload.technical_details['copy_preference']
  end

  test 'a new competing copy prevents applying an obsolete comparison' do
    approve
    @record.video_assets.create!(last_known_path: '/videos/troisieme.mkv', byte_size: 700)
    assert_equal 'blocked', apply
    assert_nil @new.reload.technical_details['copy_preference']
  end

  test 'file verification failure rolls back every preference and the journal before retry' do
    approve
    @observer.fail_verification = true
    assert_equal 'blocked', apply
    assert_nil @old.reload.technical_details['copy_preference']
    assert_nil @new.reload.technical_details['copy_preference']
    @observer.fail_verification = false
    assert_equal 'applied', apply
    assert_equal true, @new.reload.technical_details.dig('copy_preference', 'preferred')
  end

  test 'an undecidable comparison cannot run under an approved family' do
    @new.update!(byte_size: 1100)
    @planner.call
    @item = ReconciliationCase.current.sole
    approve
    assert_not @item.permitted?
    assert_equal 'skipped', apply
    assert_equal 'blocked', @item.reload.status
  end

  test 'a manual preference is preserved' do
    @old.update!(technical_details: @old.technical_details.merge('copy_preference' => { 'origin' => 'manual', 'preferred' => true }))
    @planner.call
    assert_equal 0, ReconciliationCase.current.count
    assert_equal true, @old.reload.technical_details.dig('copy_preference', 'preferred')
  end
end
