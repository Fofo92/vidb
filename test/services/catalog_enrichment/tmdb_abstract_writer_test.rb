# frozen_string_literal: true

require 'test_helper'

class TmdbAbstractWriterTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'WRAB', long_name: 'Test TMDB résumé')
    @root = Record.create!(french_title: 'Série test résumé', record_kind: 'series', language_version: language)
    entry = { 'local_season' => 1, 'local_episode' => 1, 'tmdb_season' => 1, 'tmdb_episode' => 1,
              'tmdb_episode_id' => 123, 'catalogue_title_fr' => 'Épisode test', 'title_original' => 'Test episode' }
    @item = { 'action' => 'create_proposal', 'local_mapping' => entry, 'overview_fr' => 'Résumé fourni par TMDB' }
    @plan = { 'seasons' => [{ 'local_season' => 1, 'action' => 'create_proposal', 'proposed_title' => 'Saison 01' }],
              'episodes' => [@item] }
    @mapping = Struct.new(:data).new({ 'tmdb_series_id' => 900, 'source_snapshot_retrieved_at' => nil })
  end

  test 'new TMDB episodes receive external provenance rather than fabricated manual authorship' do
    link = write.sole
    record = link.record
    assert_equal 'Résumé fourni par TMDB', record.abstract
    assert_equal 'external', record.abstract_provenance['kind']
    assert_equal 123, record.abstract_provenance.dig('source', 'external_id')
    assert_equal 'applied', link.evidence.dig('abstract_application', 'status')
  end

  test 'a manually cleared reused episode remains empty while the proposed source text is retained' do
    record = existing('Résumé initial')
    record.update!(abstract: '')
    link = write.sole
    assert_equal '', record.reload.abstract
    assert_equal 'manual', record.abstract_provenance['kind']
    assert_equal 'protected', link.evidence.dig('abstract_application', 'status')
    assert_equal 'Résumé fourni par TMDB', link.evidence['overview_fr']
  end

  test 'a reused legacy summary is preserved without retrospective attribution' do
    record = existing(nil)
    record.update_columns(abstract: 'Ancien résumé conservé', abstract_provenance: {})
    link = write.sole
    assert_equal 'Ancien résumé conservé', record.reload.abstract
    assert_equal({}, record.abstract_provenance)
    assert_equal 'protected', link.evidence.dig('abstract_application', 'status')
  end

  private

  def existing(text)
    record = Record.create!(french_title: 'Épisode test', abstract: text, language_version: @root.language_version)
    @item['action'] = 'reuse_proposal'
    @item['candidates'] = [{ 'id' => record.id }]
    record
  end

  def write
    Record.transaction do
      CatalogEnrichment::TmdbHierarchyWriter.new(root: @root, plan: @plan, mapping: @mapping).call
    end
  end
end
