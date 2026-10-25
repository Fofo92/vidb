require 'test_helper'

class EncoderProjects::EpisodeEnrichmentTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @vf = LanguageVersion.find_or_create_by!(short_name: 'VF') { |item| item.long_name = 'Version française' }
    @root = Record.create!(french_title: 'Série test', record_kind: 'series', language_version: language)
    season = @root.children.create!(french_title: 'Saison 02', rank: 2, record_kind: 'season', language_version: language)
    @record = season.children.create!(french_title: 'Le départ', rank: 1, record_kind: 'episode', language_version: language)
    @genre = Gender.find_or_create_by!(name: 'Drame')
    @country = Country.find_by(long_name: 'France') || Country.create!(long_name: 'France', short_name: 'FR')
    @candidate = { 'title' => 'Le départ', 'year' => 2025, 'abstract' => 'Résumé externe.',
                   'series_id' => @root.id, 'season' => 2, 'episode' => 1,
                   'gender_ids' => [@genre.id], 'country_ids' => [@country.id],
                   'source' => { 'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Exemple' } }
    @project = { 'language_hint' => 'VF', 'output_path' => '/videos/S02 E01 - Le départ.mkv' }
  end

  def enrichment(parameters = {}, candidate = @candidate)
    EncoderProjects::EpisodeEnrichment.new(candidate: candidate, parameters: parameters, project: @project)
  end

  test 'blank fields retain signed proposals and fill only missing metadata' do
    service = enrichment('title' => '', 'year' => '', 'abstract' => '', 'source' => '')
    assert_equal 'Le départ', service.creation_values[:title]
    assert_equal 2025, service.creation_values[:year]
    assert_no_difference('VideoAsset.count') { service.call(@record) }
    assert_equal 2025, @record.reload.year
    assert_equal 'Résumé externe.', @record.abstract
    assert_equal 'external', @record.abstract_provenance['kind']
    assert_equal [@genre.id], @record.effective_genders.map(&:id)
    assert_equal [@country.id], @record.effective_countries.map(&:id)
    assert_equal @vf.id, @record.language_version_id
    assert_empty @record.media
    assert_nil @record.length_in_mn
  end

  test 'existing manual metadata is preserved' do
    @record.update!(year: 2024, abstract: 'Résumé manuel.', language_version: @vf)
    enrichment.call(@record)
    assert_equal 2024, @record.reload.year
    assert_equal 'Résumé manuel.', @record.abstract
    assert_equal 'manual', @record.abstract_provenance['kind']
  end

  test 'a proposal for another hierarchy is rejected before enrichment' do
    assert_raises(ArgumentError) { enrichment({}, @candidate.merge('season' => 3)).call(@record) }
    assert_nil @record.reload.year
  end

  test 'a missing external field remains available for manual input' do
    candidate = @candidate.except('year', 'abstract')
    service = enrichment({ 'year' => '2026', 'abstract' => 'Résumé saisi.' }, candidate)
    service.call(@record)
    assert_equal 2026, @record.reload.year
    assert_equal 'Résumé saisi.', @record.abstract
    assert_equal 'manual', @record.abstract_provenance['kind']
  end
  test 'an explicit editorial correction is applied while preserving later concurrent changes' do
    @record.update!(year: 2024, abstract: 'Résumé manuel.')
    candidate = @candidate.merge('year' => 2024, 'abstract' => 'Résumé manuel.')
    enrichment({ 'year' => '2026', 'abstract' => 'Résumé corrigé.' }, candidate).call(@record)
    assert_equal 2026, @record.reload.year
    assert_equal 'Résumé corrigé.', @record.abstract
    assert_equal 'manual', @record.abstract_provenance['kind']
    assert_raises(ArgumentError) { enrichment({ 'year' => '2025' }, candidate).call(@record) }
    assert_equal 2026, @record.reload.year
  end

  test 'too many genres rolls back enrichment rather than leaving a partially modified record' do
    @record.reload
    candidate = @candidate.merge('gender_ids' => [1, 2, 3])
    assert_raises(ArgumentError) { enrichment({}, candidate).call(@record) }
    assert_nil @record.reload.year
    assert @record.abstract.blank?
  end

end
