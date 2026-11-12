require 'test_helper'

class CopyConditionsHelperTest < ActiveSupport::TestCase
  include CopyConditionsHelper
  Copy = Struct.new(:effective_condition)

  test 'unknown is displayed without claiming a healthy complete copy' do
    assert_equal ['Intégralité non vérifiée', 'Détérioration non évaluée'], copy_condition_lines(Copy.new({}))
  end

  test 'retained duration and the missing side remain explicit' do
    details = { 'integrality' => 'incomplete', 'damage' => 'severe', 'retained_portion' => 'beginning',
                'retained_duration_seconds' => 2460, 'needs_review' => true }
    lines = copy_condition_lines(Copy.new(details))
    assert_includes lines, 'Durée conservée : 41 min'
    assert_includes lines, 'Début conservé — fin manquante'
    assert_includes lines, 'Plus sévèrement détériorée (dd)'
    assert_includes lines, 'Marqueurs à qualifier'
  end

  test 'summary stays compact while exact seconds remain visible' do
    asset = Copy.new({ 'integrality' => 'incomplete', 'damage' => 'light', 'retained_duration_seconds' => 2371 })
    assert_equal 'Incomplète · d · 39 min 31 s', copy_condition_summary(asset)
    assert_includes copy_condition_lines(asset), 'Durée conservée : 39 min 31 s'
  end

end
