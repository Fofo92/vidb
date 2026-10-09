# frozen_string_literal: true

require 'test_helper'

class EncodingPilotTitlesTest < ActiveSupport::TestCase
  test 'accepted local titles retain the complete external identity and provenance' do
    result = service.call(entry)
    assert_equal 'Virus', result['catalogue_title_fr']
    assert_equal 'Sick Day', result['catalogue_title_original']
    assert_equal 'Sick Day (1)', result['title_original']
    assert_equal 'Virus (1)', result.dig('title_decision', 'tmdb_title_fr')
  end

  test 'unlisted episodes are not stripped automatically' do
    input = entry.merge(tmdb_episode_id: 999)
    result = service.call(input)
    assert_equal 'Virus (1)', result['catalogue_title_fr']
    assert_not result.key?('catalogue_title_original')
  end

  test 'a changed external title requires review' do
    assert_raises(ArgumentError) { service.call(entry.merge(title_original: 'Another episode (1)')) }
  end

  private

  def entry
    { tmdb_episode_id: 6058269, catalogue_title_fr: 'Virus (1)', title_original: 'Sick Day (1)' }
  end

  def service
    overrides = { '6058269' => { title_fr: 'Virus', title_original: 'Sick Day' } }
    CatalogEnrichment::EncodingPilotTitles.new(overrides: overrides)
  end
end
