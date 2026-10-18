require 'test_helper'
require 'minitest/mock'

class ReconciliationWorkbenchSeriesCreationTest < ActiveSupport::TestCase
  def document(title = 'Série nouvelle', episode = 'La découverte')
    { 'format' => 'vidb.series_structure_preparation', 'version' => 1,
      'series_group_count' => 1, 'file_count' => 1, 'inventory_at' => Time.current.iso8601,
      'inputs' => [], 'reference_attribution' => 'Guide sourcé', 'groups' => [{ 'name' => title,
        'directory' => "/videos/#{title}", 'file_count' => 1,
        'proposed_existing_root' => nil, 'proposed_new_root' => { 'french_title' => title },
        'other_same_title_roots' => [], 'reference_url' => 'https://example.org/series',
        'reference_show' => { 'name' => title }, 'files' => [{
          'path' => "/videos/#{title}/Saison 03/S03 E01 - #{episode}.mkv", 'observed_title' => episode,
          'local_season' => 3, 'local_episode' => 1, 'existing_season_candidates' => [],
          'reference_same_number' => [{ 'name' => episode, 'season' => 3, 'number' => 1,
            'url' => 'https://fr.wikipedia.org/wiki/Exemple' }] }] }] }
  end

  def approve(items)
    rule = ReconciliationWorkbench::Rules::SERIES_CREATION
    ReconciliationRuleDecision.create!(rule_key: rule.key, rule_version: rule.version,
      decision: 'approved', case_fingerprints: items.map(&:fingerprint))
  end

  test 'one family creates several complete series atomically without importing files or guessing their languages' do
    source = document
    source['groups'] += document('Autre série', 'Le retour')['groups']
    source.merge!('series_group_count' => 2, 'file_count' => 2)
    items = ReconciliationWorkbench::Proposals.new.call(source)
    assert_equal 0, Record.count
    assert_equal 0, LanguageVersion.count
    assert_equal 2, items.size
    assert items.none?(&:permitted?)
    approve(items)
    items.each { |item| assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item) }
    assert_equal 6, Record.count
    assert_equal 1, LanguageVersion.count
    assert_equal ['IND'], Record.all.map { |record| record.language_version.short_name }.uniq
    assert_equal ['Saison 3'], Record.where(record_kind: 'season').pluck(:french_title).uniq
    assert_equal 0, VideoAsset.count
    assert_not ReconciliationRuleDecision.exists?(rule_key: ReconciliationWorkbench::Rules::DISK.key)
    repeated = ReconciliationWorkbench::Proposals.new.call(source)
    assert_equal items.map(&:id), repeated.map(&:id)
    assert_equal 'skipped', ReconciliationWorkbench::Executor.new.call(repeated.first)
    assert_equal 6, Record.count
  end

  test 'a concurrent identity blocks creation even when it was manually added after approval' do
    item = ReconciliationWorkbench::Proposals.new.call(document).sole
    approve([item])
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    existing = Record.create!(french_title: 'Série nouvelle', language_version: language)
    assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal [existing.id], Record.ids
    assert_not LanguageVersion.exists?(short_name: 'IND')
    assert_match 'identité concurrente', item.reload.error
  end

  test 'new episodes preserve the viewing information in a seen directory without moving any file' do
    source = document
    source['groups'][0]['files'][0]['path'].sub!('/Saison', '/_vus/Saison')
    item = ReconciliationWorkbench::Proposals.new.call(source).sole
    assert_equal true, item.payload['operations'].sole['is_seen']
    approve([item])
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    episode = Record.find(item.reload.result['episodes'].sole['episode_id'])
    assert_equal true, episode.is_seen
    assert_equal 'La découverte', episode.french_title
    assert_equal 0, VideoAsset.count
  end

  test 'an existing homonym never becomes a new series or inherits a structure approval' do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    Record.create!(french_title: 'Série nouvelle', language_version: language)
    item = ReconciliationWorkbench::Proposals.new.call(document).sole
    assert_equal 'blocked', item.status
    assert_empty item.payload['operations']
    assert_equal 1, Record.count
    rule = ReconciliationWorkbench::Rules::SOURCED_STRUCTURE
    ReconciliationRuleDecision.create!(rule_key: rule.key, rule_version: rule.version, decision: 'approved')
    assert_not item.permitted?
  end

  test 'a failure during episode creation rolls back the root seasons and unknown language together' do
    item = ReconciliationWorkbench::Proposals.new.call(document).sole
    approve([item])
    failing = ->(*) { raise 'Échec simulé' }
    ReconciliationWorkbench::SeriesStructureAction.stub(:new, failing) do
      assert_equal 'blocked', ReconciliationWorkbench::Executor.new.call(item)
    end
    assert_equal 0, Record.count
    assert_equal 0, LanguageVersion.count
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal 3, Record.count
  end

  test 'missing or contradictory series identity cannot introduce a creation proposal' do
    source = document
    source['groups'][0]['reference_show']['name'] = 'Autre identité'
    assert_raises(ArgumentError) { ReconciliationWorkbench::Proposals.new.call(source) }
    assert_equal 0, ReconciliationCase.count
  end

  test 'a sourced new series may contain an episode homonymous with an unrelated work without changing it' do
    language = LanguageVersion.create!(short_name: 'VF', long_name: 'Français')
    film = Record.create!(french_title: 'La découverte', record_kind: 'standalone_video', language_version: language)
    before = film.attributes
    item = ReconciliationWorkbench::Proposals.new.call(document).sole
    assert_equal 1, item.payload['operations'].size
    approve([item])
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(item)
    assert_equal before, film.reload.attributes
    episode = Record.find(item.reload.result['episodes'].sole['episode_id'])
    assert_equal 'episode', episode.record_kind
    assert_equal 'Série nouvelle', episode.root.french_title
    assert_not_equal film.id, episode.id
  end
end
