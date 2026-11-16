require 'test_helper'

class VideoAssets::ConditionConventionApplyTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |row| row.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Film', record_kind: 'standalone_video', language_version: language)
  end

  def copy(name, details = {})
    asset = VideoAsset.create!(record: @record, status: 'present', last_known_path: "/videos/#{name}.mkv")
    asset.update_columns(condition_details: details)
    asset
  end

  def plan_for(*assets)
    plan = VideoAssets::ConditionConventionPlan.new.call
    plan['changes'].select! { |row| assets.map(&:id).include?(row.fetch('video_asset_id')) }
    plan['plan_digest'] = VideoAssets::ConditionConventionPlan.digest(plan['changes'])
    plan
  end

  test 'preview writes neither copies nor records' do
    asset = copy('Unmarked')
    before = asset.attributes.deep_dup
    record_before = @record.reload.attributes.deep_dup
    plan = plan_for(asset)
    assert_equal 1, plan['changes'].size
    assert_equal before, asset.reload.attributes
    assert_equal record_before, @record.reload.attributes
  end

  test 'apply changes only condition metadata and timestamps including absent copies' do
    asset = copy('Unmarked')
    asset.update_columns(status: 'missing')
    before = asset.reload.attributes.except('condition_details', 'updated_at')
    record_before = @record.reload.attributes.deep_dup
    plan = plan_for(asset)
    result = VideoAssets::ConditionConventionApply.new.call(plan)
    assert_equal 1, result.fetch('counts')['applied']
    assert_equal 'complete', asset.reload.condition_details['integrality']
    assert_equal 'none', asset.condition_details['damage']
    assert_not asset.integrality_verified?
    assert_equal before, asset.attributes.except('condition_details', 'updated_at')
    assert_equal record_before, @record.reload.attributes
    result = VideoAssets::ConditionConventionApply.new.call(plan)
    assert_equal 1, result.fetch('counts')['already_applied']
  end

  test 'beginning-only files become incomplete without changing availability or inventing duration' do
    asset = copy('Film (début)')
    record_before = @record.reload.attributes.deep_dup
    VideoAssets::ConditionConventionApply.new.call(plan_for(asset))
    assert_equal true, asset.reload.content_incomplete?
    assert_equal 'beginning', asset.condition_details['retained_portion']
    assert_nil asset.condition_details['retained_duration_seconds']
    assert_equal 'present', asset.status
    assert_equal record_before, @record.reload.attributes
  end

  test 'a manual change after preview aborts and rolls back every earlier write in the batch' do
    first = copy('First')
    second = copy('Second')
    plan = plan_for(first, second)
    manual = { 'integrality' => 'incomplete', 'damage' => 'light', 'note' => 'Qualification récente' }
    second.update_columns(condition_details: manual)
    assert_raises(ArgumentError) { VideoAssets::ConditionConventionApply.new.call(plan) }
    assert_equal({}, first.reload.condition_details)
    assert_equal manual, second.reload.condition_details
  end

  test 'a renamed copy or a modified plan is never blindly applied' do
    asset = copy('Original')
    plan = plan_for(asset)
    asset.update_columns(last_known_path: '/videos/Renamed.mkv')
    assert_raises(ArgumentError) { VideoAssets::ConditionConventionApply.new.call(plan) }
    plan['changes'].first['after']['damage'] = 'severe'
    assert_raises(ArgumentError) { VideoAssets::ConditionConventionApply.new.call(plan) }
    assert_equal({}, asset.reload.condition_details)
    assert_raises(ArgumentError) { VideoAssets::ConditionConventionApply.new.call({}) }
  end

  test 'manual states and ambiguous markers are not proposed for replacement' do
    manual = copy('Film (d)', { 'integrality' => 'unknown', 'damage' => 'unknown' })
    ambiguous = copy('Other (début 41)')
    plan = VideoAssets::ConditionConventionPlan.new.call
    assert_not plan['changes'].any? { |row| [manual.id, ambiguous.id].include?(row['video_asset_id']) }
    assert plan['needs_review'].any? { |row| row['video_asset_id'] == ambiguous.id }
  end

  test 'a defect mentioned on the record prevents presuming its unidentified copies healthy' do
    asset = copy('File without marker')
    @record.update!(french_title: 'Film (d)')
    plan = VideoAssets::ConditionConventionPlan.new.call
    assert_not plan['changes'].any? { |row| row['video_asset_id'] == asset.id }
    assert plan['needs_review'].any? { |row| row['video_asset_id'] == asset.id }
  end

  test 'a new defect indication on the record after preview stops the application' do
    asset = copy('File without marker')
    plan = plan_for(asset)
    @record.update!(french_title: 'Film (i)')
    assert_raises(ArgumentError) { VideoAssets::ConditionConventionApply.new.call(plan) }
    assert_equal({}, asset.reload.condition_details)
  end

  test 'a beginning marker shared by the record and the file is unambiguous' do
    @record.update!(french_title: 'Film (début)')
    asset = copy('Film (début)')
    plan = plan_for(asset)
    assert_equal 1, plan['changes'].size
    VideoAssets::ConditionConventionApply.new.call(plan)
    assert_equal true, asset.reload.content_incomplete?
    assert_equal 'beginning', asset.condition_details['retained_portion']
  end
end
