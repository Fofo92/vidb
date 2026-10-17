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

  def confirm_manual(asset_id = @new.id)
    user = User.create!(email: 'copy-review@example.com', password: 'password')
    digest = ReconciliationWorkbench::Snapshot.digest([@item.fingerprint])
    ReconciliationWorkbench::CopyArbitration.new(user: user, choices: { @item.id.to_s => asset_id.to_s },
      scope_digest: digest, comment: 'Copie récente et sous-titrée, piste originale vérifiée').call
    @source = @item
    @item = ReconciliationCase.current.find_by!(rule_key: ReconciliationWorkbench::Rules::MANUAL_COPY.key)
  end

  test 'manual choice applies unknown language evidence without changing languages or approving a recurring rule' do
    details = @new.technical_details.deep_dup
    details['streams'].last['tags']['language'] = 'qaa'
    @new.update!(technical_details: details)
    @planner.call
    @item = ReconciliationCase.current.sole
    assert_not @item.permitted?
    confirm_manual
    assert_not @source.reload.active?
    @planner.call
    assert_equal [@item.id], ReconciliationCase.current.pluck(:id)
    assert_equal 'applied', apply
    assert_equal 'manual', @new.reload.technical_details.dig('copy_preference', 'origin')
    assert_equal 'qaa', @new.technical_details['streams'].last.dig('tags', 'language')
    assert_equal @new.id, @item.reload.result.dig('manual_review', 'preferred_asset_id')
    assert_not ReconciliationRuleDecision.exists?(rule_key: ReconciliationWorkbench::Rules::PREFERENCE.key)
    assert_equal 'skipped', apply
    @planner.call
    assert_equal 0, ReconciliationCase.current.where(rule_key: ReconciliationWorkbench::Rules::PREFERENCE.key).count
  end

  test 'deferring a queued manual choice allows the original comparison to be examined again' do
    confirm_manual
    decision = ReconciliationRuleDecision.find_by!(rule_key: ReconciliationWorkbench::Rules::MANUAL_COPY.key)
    decision.update!(decision: 'deferred')
    @planner.call
    assert @source.reload.active?
    assert_not @item.reload.permitted?
  end

  test 'manual choices preserve the existing block on edited catalogue metadata' do
    confirm_manual
    @record.update!(abstract: 'Correction après arbitrage')
    assert_equal 'blocked', apply
    assert_nil @new.reload.technical_details['copy_preference']
    assert_match 'modifiée depuis la proposition', @item.reload.error
  end

  test 'manual choices are still blocked after file measurement changes' do
    confirm_manual
    samples = @observer.measure(@observer.inputs([@old, @new]))
    samples.last['measurement']['measured_duration_seconds'] += 1
    @observer.stub(:measure, samples) { assert_equal 'blocked', apply }
    assert_nil @new.reload.technical_details['copy_preference']
    assert_match 'mesures ont changé', @item.reload.error
  end

  test 'manual preference and journal roll back on final physical verification failure and can resume' do
    confirm_manual(@old.id)
    @observer.fail_verification = true
    assert_equal 'blocked', apply
    assert_nil @old.reload.technical_details['copy_preference']
    @observer.fail_verification = false
    assert_equal 'applied', apply
    assert_equal true, @old.reload.technical_details.dig('copy_preference', 'preferred')
  end

  test 'a manual preference is preserved' do
    @old.update!(technical_details: @old.technical_details.merge('copy_preference' => { 'origin' => 'manual', 'preferred' => true }))
    @planner.call
    assert_equal 0, ReconciliationCase.current.count
    assert_equal true, @old.reload.technical_details.dig('copy_preference', 'preferred')
  end
end
