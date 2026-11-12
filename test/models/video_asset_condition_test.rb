require 'test_helper'

class VideoAssetConditionTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @series = Record.create!(french_title: 'Pilote', record_kind: 'series', language_version: language)
    @season = @series.children.create!(french_title: 'Saison 1', rank: 1, record_kind: 'season', language_version: language)
    @episode = @season.children.create!(french_title: 'Épisode 1', rank: 1, record_kind: 'episode', language_version: language)
  end

  def copy(name, **options)
    @episode.video_assets.create!({ last_known_path: "/videos/S01 E01 - #{name}.mkv" }.merge(options))
  end

  test 'new marked copies retain condition independently from technical observations and future path changes' do
    asset = copy('Titre (dd)')
    before = asset.condition_details.deep_dup
    assert_equal 'severe', before['damage']
    asset.update!(last_known_path: '/videos/S01 E01 - Titre.mkv', technical_details: { 'streams' => [] })
    assert_equal before, asset.reload.condition_details
    assert_equal '/videos/S01 E01 - Titre (dd).mkv', before['evidence'].first['source_path']
  end

  test 'incomplete content does not change physical availability or recorded state' do
    asset = copy("Titre (début 41')")
    assert asset.content_incomplete?
    assert @episode.reload.is_available
    assert @episode.is_recorded
    records = [@series, @season, @episode]
    assert_includes RecordCompleteness.new(records: records).ids('incomplete'), @series.id
    copy('Copie intégrale', condition_details: { 'integrality' => 'complete', 'damage' => 'none' })
    assert_includes RecordCompleteness.new(records: records.map(&:reload)).ids('complete'), @series.id
  end

  test 'whole lightly damaged or severely damaged copies remain available and unknown does not certify integrality' do
    asset = copy('Titre (d)')
    assert VideoAssets::PartCoverage.integral_available?([asset], expected_parts: 1)
    refute asset.integrality_verified?
    unmarked = copy('Autre')
    assert_equal({}, unmarked.condition_details)
    refute unmarked.integrality_verified?
  end

  test 'partial copies cannot be assembled implicitly and declared broadcast parts still require all parts' do
    first = copy("Titre (début 41')")
    last = copy("Titre (fin 20')")
    refute VideoAssets::PartCoverage.integral_available?([first, last], expected_parts: 1)
    @episode.update!(broadcast_part_count: 2)
    one = copy('Partie 1', broadcast_part_number: 1)
    two = copy('Partie 2', broadcast_part_number: 2)
    assert VideoAssets::PartCoverage.integral_available?([one, two], expected_parts: 2)
  end

  test 'invalid or contradictory qualification is rejected' do
    asset = copy('Titre')
    [{ 'integrality' => 'complete', 'retained_portion' => 'beginning' },
     { 'integrality' => 'incomplete', 'retained_duration_seconds' => -1 },
     { 'damage' => 'invented' }, { 'note' => 12 }, { 'evidence' => 'wrong' }].each do |details|
      asset.condition_details = details
      refute asset.valid?, details.inspect
    end
  end
end
