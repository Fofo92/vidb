# frozen_string_literal: true

require 'test_helper'

class TmdbHierarchyApplicationTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IN', long_name: 'Non qualifiée')
    @root = Record.create!(french_title: 'Poirot', language_version: language)
    @existing = Record.create!(french_title: 'Les Pendules', original_title: 'The Clocks', rank: 1,
                               language_version: language, abstract: 'Résumé personnel', year: 2009,
                               length_in_mn: 86, is_seen: true, is_checked: true, is_recorded: true)
    @snapshot = { format: 'vidb.tmdb_series_snapshot', version: 1, tmdb_series_id: 790,
                  episodes: [external(90, 4, 'Les Pendules', 'The Clocks'), external(91, 1, 'Drame', 'Tragedy')] }
    @mapping = { format: 'vidb.local_tmdb_episode_mapping', version: 1, root_record_id: @root.id,
                 series_title: 'Poirot', tmdb_series_id: 790,
                 episodes: [entry(90, 1, 4, 'Les Pendules', 'The Clocks').merge(expected_record: signature(@existing)),
                            entry(91, 2, 1, 'Drame', 'Tragedy')] }
    @plan = build_plan
  end

  test 'preview creates no records or external links' do
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count', 'VideoAsset.count']) do
      assert_equal 'preview', service.call[:status]
    end
    assert_equal 'undetermined', @root.reload.record_kind
    assert_nil @existing.reload.ancestry
  end

  test 'apply preserves personal metadata and records separate local and external numbering' do
    assert_difference('Record.count', 2) do
      assert_difference('CatalogueEpisodeLink.count', 2) do
        assert_no_difference('VideoAsset.count') { assert service.call(apply: true)[:applied] }
      end
    end
    assert_equal 'series', @root.reload.record_kind
    assert_equal 'Résumé personnel', @existing.reload.abstract
    assert_equal 2009, @existing.year
    assert_equal 86, @existing.length_in_mn
    assert @existing.is_seen
    assert @existing.is_checked
    assert @existing.is_recorded
    link = CatalogueEpisodeLink.find_by!(record: @existing)
    assert_equal 1, link.local_episode_number
    assert_equal 4, link.external_episode_number
    created = @root.children.sole.children.find_by!(rank: 2)
    assert_nil created.year
    assert_nil created.length_in_mn
    assert_nil created.is_seen
    assert_nil created.is_available
    assert_not created.is_checked
    assert_equal 'Résumé externe', created.abstract
  end

  test 'rerun is idempotent and preserves subsequent editorial changes' do
    service.call(apply: true)
    @existing.update!(abstract: 'Résumé corrigé')
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count']) do
      assert_equal 'already_applied', service.call(apply: true)[:status]
    end
    assert_equal 'Résumé corrigé', @existing.reload.abstract
  end

  test 'changed hierarchy blocks applying an obsolete plan' do
    @existing.update!(rank: 8)
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count']) do
      assert_raises(ArgumentError) { service.call(apply: true) }
    end
    assert_equal 'undetermined', @root.reload.record_kind
  end

  test 'a late failure rolls back existing placements new records and links' do
    validation = -> { errors.add(:base, 'Late failure') if french_title == 'Drame' }
    Record.validate validation
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count']) do
      assert_raises(ActiveRecord::RecordInvalid) { service.call(apply: true) }
    end
    assert_nil @existing.reload.ancestry
    assert_equal 'undetermined', @root.reload.record_kind
  ensure
    Record.skip_callback(:validate, :before, validation) if validation
  end

  test 'a new title collision blocks creation instead of duplicating records' do
    Record.create!(french_title: 'Drame', language_version: @root.language_version)
    assert_no_difference(['Record.count', 'CatalogueEpisodeLink.count']) do
      assert_raises(ArgumentError) { service.call(apply: true) }
    end
  end

  private

  def external(id, number, french, original)
    { tmdb_episode_id: id, season_number: 12, episode_number: number, title_fr: french,
      title_original: original, overview_fr: 'Résumé externe', first_air_date: '2011-12-26',
      reference_runtime_minutes: 92 }
  end

  def entry(id, local, external_number, french, original)
    { local_season: 12, local_episode: local, tmdb_season: 12, tmdb_episode: external_number,
      tmdb_episode_id: id, catalogue_title_fr: french, title_original: original }
  end

  def signature(record)
    record.attributes.slice(*CatalogEnrichment::TmdbHierarchyApplication::COLUMNS)
  end

  def build_plan
    catalogue = Record.all.map { |record| signature(record) }
    CatalogEnrichment::TmdbHierarchyPlan.new(mapping: @mapping, snapshot: @snapshot, catalogue: catalogue).call
  end

  def service
    CatalogEnrichment::TmdbHierarchyApplication.new(mapping: @mapping, snapshot: @snapshot, plan: @plan)
  end
end
