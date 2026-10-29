require 'test_helper'

class TvGuideAcquisitionsHelperTest < ActiveSupport::TestCase
  include TvGuideAcquisitionsHelper

  def tone(kind = nil, previous: nil, scheduled: nil, selected: false)
    acquired = Struct.new(:kind).new(kind) if kind
    tv_guide_acquisition_tone(acquired: acquired, previous: previous, scheduled: scheduled, selected: selected)
  end

  test 'green covers new acquisitions old copies and unavailable copies' do
    assert_equal 'recommended', tone
    %w[reencode history recorded].each { |kind| assert_equal 'recommended', tone(kind) }
  end

  test 'orange covers encoded copies and existing sources including quarantine' do
    %w[available capture quarantine].each { |kind| assert_equal 'unnecessary', tone(kind) }
    assert_equal 'unnecessary', tone(previous: Object.new)
  end

  test 'an existing schedule makes a second capture unnecessary even for an old copy' do
    assert_equal 'unnecessary', tone('reencode', scheduled: Object.new)
    assert_equal 'unnecessary', tone('reencode', selected: true)
    assert_equal 'unnecessary', tone('project_review', scheduled: Object.new)
  end

  test 'uncertain project evidence stays neutral and all colors have textual advice' do
    assert_equal 'review', tone('project_review')
    assert_equal 'review', tone('unknown-future-kind')
    assert_equal 'Nouvelle capture utile', tv_guide_acquisition_advice('recommended')
    assert_equal 'Nouvelle capture non nécessaire', tv_guide_acquisition_advice('unnecessary')
    assert_equal 'Acquisition à vérifier', tv_guide_acquisition_advice('review')
  end
end
