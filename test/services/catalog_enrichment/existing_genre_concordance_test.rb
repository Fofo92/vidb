# frozen_string_literal: true
require 'test_helper'

class ExistingGenreConcordanceTest < ActiveSupport::TestCase
  def decide(current, ids, flags = [])
    CatalogEnrichment::ExistingGenreConcordance.new.call(current: current,
      external: ids.map { |id| { 'id' => id } }, review_flags: flags)
  end
  test 'existing two genres remain corroborated when the source lists a third' do
    result = decide(['Comédie', 'Drame'], [35, 18, 10749])
    assert_equal 'corroborated', result[:status]
    assert_equal ['Comédie', 'Drame'], result[:retained_genres]
    assert_equal ['Romance'], result[:unused_external_genres]
    assert_equal false, result[:changed]
  end
  test 'one existing genre need not be expanded' do
    assert_equal ['Policier'], decide(['Policier'], [80, 18, 53])[:retained_genres]
  end
  test 'missing and excessive existing genres are never filled or truncated' do
    assert_equal 'needs_review', decide([], [35, 18])[:status]
    assert_equal 'needs_review', decide(['Action', 'Comédie', 'Drame'], [28, 35, 18])[:status]
  end
  test 'a source omitting an existing genre stays under review' do
    result = decide(['Comédie', 'Drame'], [18])
    assert_equal 'needs_review', result[:status]
    assert_equal ['Comédie'], result[:unsupported_genres]
  end
  test 'biography and espionage reservations take precedence over generic concordance' do
    flags = [{ 'code' => 'biographical_classification' }]
    result = decide(['Drame'], [18], flags)
    assert_equal 'needs_review', result[:status]
    assert_equal flags, result[:review_flags]
  end
  test 'a documentary source requires category review' do
    assert_equal 'needs_review', decide(['Drame'], [18, 99])[:status]
  end
  test 'a medium tag or unknown extra genre does not invalidate positive support' do
    assert_equal 'corroborated', decide(['Drame'], [18, 10770])[:status]
    assert_equal 'corroborated', decide(['Policier'], [80, 9648])[:status]
  end
  test 'unmapped labels never prove an unsupported existing genre' do
    assert_equal 'needs_review', decide(['Policier'], [9648])[:status]
  end
  test 'input arrays and hashes are preserved' do
    current = ['Drame'].freeze
    external = [{ 'id' => 18 }.freeze].freeze
    result = CatalogEnrichment::ExistingGenreConcordance.new.call(current: current, external: external)
    assert_equal ['Drame'], current
    assert_equal [{ 'id' => 18 }], external
    assert_equal 'corroborated', result[:status]
  end
end
