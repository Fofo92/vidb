require 'test_helper'

class EncoderProjects::CatalogueRuntimeTest < ActiveSupport::TestCase
  RecordDouble = Struct.new(:length_in_mn, :minimum_catalogue_length) do
    def update!(length_in_mn:)
      self.length_in_mn = length_in_mn
    end
  end

  test 'a known duration is preserved and a missing duration can be completed' do
    existing = RecordDouble.new(41, 10)
    EncoderProjects::CatalogueRuntime.import(existing, 'reference_runtime_minutes' => 44)
    assert_equal 41, existing.length_in_mn
    empty = RecordDouble.new(nil, 10)
    EncoderProjects::CatalogueRuntime.import(empty, 'reference_runtime_minutes' => 44)
    assert_equal 44, empty.length_in_mn
  end

  test 'missing invalid and unsupported catalogue durations do not change the record' do
    [nil, 0, -1, 9, 241, '40', 40.5, true].each do |duration|
      record = RecordDouble.new(nil, 10)
      EncoderProjects::CatalogueRuntime.import(record, 'reference_runtime_minutes' => duration)
      assert_nil record.length_in_mn
    end
    animation = RecordDouble.new(nil, 3)
    EncoderProjects::CatalogueRuntime.import(animation, 'reference_runtime_minutes' => 5)
    assert_equal 5, animation.length_in_mn
  end

  test 'only explicit unambiguous text and ISO durations are parsed' do
    assert_equal 100, EncoderProjects::CatalogueRuntime.from_text('1 h 40 min')
    assert_equal 106, EncoderProjects::CatalogueRuntime.from_text('106 minutes')
    assert_equal 60, EncoderProjects::CatalogueRuntime.from_text('1 heure')
    assert_nil EncoderProjects::CatalogueRuntime.from_text('40 ou 50 minutes')
    assert_nil EncoderProjects::CatalogueRuntime.from_text('')
    assert_equal 100, EncoderProjects::CatalogueRuntime.from_iso('PT1H40M')
    assert_equal 44, EncoderProjects::CatalogueRuntime.from_iso('PT44M')
    assert_nil EncoderProjects::CatalogueRuntime.from_iso('PT')
    assert_nil EncoderProjects::CatalogueRuntime.from_iso('unknown')
  end

  test 'runtime is shared only for a unique concordant film identity' do
    wiki = { 'french_title' => 'Film', 'year' => 2026 }
    tmdb = wiki.merge('reference_runtime_minutes' => 100)
    enriched = EncoderProjects::CatalogueRuntime.enrich([wiki, tmdb])
    assert_equal 100, enriched.first['reference_runtime_minutes']
    assert_nil wiki['reference_runtime_minutes']
    other = tmdb.merge('year' => 2025)
    assert_nil EncoderProjects::CatalogueRuntime.enrich([wiki, other]).first['reference_runtime_minutes']
    competing = tmdb.merge('reference_runtime_minutes' => 90)
    assert_nil EncoderProjects::CatalogueRuntime.enrich([wiki, tmdb, competing]).first['reference_runtime_minutes']
  end
end
