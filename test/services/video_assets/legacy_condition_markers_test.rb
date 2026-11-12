require 'test_helper'

module VideoAssets
  class LegacyConditionMarkersTest < ActiveSupport::TestCase
    def parse(name)
      LegacyConditionMarkers.call("/videos/Séries TV/Série/Saison 01/#{name}.mkv")
    end

    test 'd and dd describe distinct damage without asserting integrality' do
      assert_equal 'light', parse('S01 E01 (d) - Titre')['damage']
      assert_equal 'severe', parse('S01 E01 (dd) - Titre')['damage']
      assert_equal 'unknown', parse('S01 E01 (d) - Titre')['integrality']
      assert_equal 'severe', parse('Film (d) (dd)')['damage']
    end

    test 'beginning and end durations describe retained content in seconds' do
      beginning = parse("Film (début 41')")
      assert_equal 'incomplete', beginning['integrality']
      assert_equal 'beginning', beginning['retained_portion']
      assert_equal 2460, beginning['retained_duration_seconds']
      assert_equal ["(début 41')"], beginning['evidence'].first['markers']
      assert_equal 'end', parse('Film (fin 41 min)')['retained_portion']
      assert_equal 2460, parse('Film (fin 41’)')['retained_duration_seconds']
    end

    test 'i is incomplete without inventing a missing portion or duration' do
      result = parse('Film (i) (d)')
      assert_equal 'incomplete', result['integrality']
      assert_equal 'unknown', result['retained_portion']
      assert_nil result['retained_duration_seconds']
      assert_equal 'light', result['damage']
    end

    test 'ambiguous duration and conflicting portions need review and still signal incomplete content' do
      ["Film (début 41)", "Film (début 41') (fin 20')", "Film (fin 0')"].each do |name|
        result = parse(name)
        assert result['needs_review']
        assert_equal 'incomplete', result['integrality']
        assert_nil result['retained_duration_seconds']
      end
    end

    test 'unmarked names and upper case Roman numbers do not prove good condition' do
      assert_equal({}, parse('Titre (I)'))
      assert_equal({}, parse('Titre'))
      assert_equal({}, LegacyConditionMarkers.call('/videos/Série (d)/Film.mkv'))
    end
    test 'minute second and hour minute markers preserve exact retained durations' do
      assert_equal 2371, parse("Film (fin 39'31)")['retained_duration_seconds']
      assert_equal 4140, parse('Film (fin 1h09)')['retained_duration_seconds']
      refute parse("Film (fin 39'31)")['needs_review']
      assert parse("Film (fin 39'60)")['needs_review']
    end

  end
end
