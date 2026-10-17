# frozen_string_literal: true
require 'test_helper'
require 'tmpdir'
require 'json'
require 'fileutils'
class FilmMetadataApplicationTest < ActiveSupport::TestCase
  self.use_transactional_tests = false
  setup do
    @reference_counts = [Record.count, Gender.count, LanguageVersion.count]
    @directory = File.join(Dir.mktmpdir('vidb-film-metadata-', '/tmp'), 'journal')
    @genres = %w[Drame Romance].map { |name| Gender.create!(name: "FMA test #{name}") }
    @language = LanguageVersion.create!(short_name: 'FMA_TEST', long_name: 'Version pour test de métadonnées')
    @record = Record.create!(french_title: 'Film test', original_title: '', year: 2022,
                             record_kind: 'standalone_video', abstract: 'Résumé corrigé à préserver.',
                             language_version: @language)
    @operation = 'fixture-initial-films'
    @entry = { 'status' => 'candidate', 'identity' => { 'tmdb_id' => 42, 'supported' => true },
               'local' => local_snapshot, 'proposal' => {
                 'source' => { 'provider' => 'tmdb', 'external_id' => 42 },
                 'year' => { 'status' => 'candidate', 'current' => 2022, 'proposed' => 2022,
                             'date' => '2022-01-01', 'year_basis' => 'first_release',
                             'reference' => { 'policy' => 'first_public_release_v1',
                                              'selected' => { 'date' => '2022-01-01', 'type' => 1 } } },
                 'genres' => { 'status' => 'candidate', 'proposed' => ['FMA test Drame', 'FMA test Romance'] }
               } }
    @service = CatalogEnrichment::FilmMetadataApplication.new(journal_directory: @directory, operation: @operation)
  end
  teardown do
    @record.destroy! if @record&.persisted?
    @genres&.each(&:destroy!)
    @language&.destroy!
    assert_equal @reference_counts, [Record.count, Gender.count, LanguageVersion.count]
    FileUtils.remove_entry(File.dirname(@directory)) if @directory && File.directory?(File.dirname(@directory))
  end
  def local_snapshot
    @record.attributes.slice('french_title','original_title','year','year_basis','year_evidence','abstract')
           .merge('record_id' => @record.id, 'genres' => @record.genders.map(&:name).sort)
  end
  def apply
    @service.call(entry: @entry, apply: true)
  end
  def journal
    CatalogEnrichment::FilmMetadataJournal.new(directory: @directory)
  end
  test 'preview creates neither changes nor a journal' do
    assert_equal 'ready', @service.call(entry: @entry)[:status]
    assert_equal 'unknown', @record.reload.year_basis
    assert_not File.exist?(@directory)
  end
  test 'qualifies year fills missing genres archives old year and preserves other attributes' do
    before = @record.attributes.except('year','year_basis','year_evidence','year_history','updated_at', 'genre_provenance')
    result = apply
    assert_equal 'applied', result[:status]
    assert_equal 'first_release', @record.reload.year_basis
    assert_equal ['FMA test Drame','FMA test Romance'], @record.genders.map(&:name).sort
    assert_equal 1, @record.year_history.size
    assert_equal 'unknown', @record.year_history.first['basis']
    assert_equal before, @record.attributes.except('year','year_basis','year_evidence','year_history','updated_at', 'genre_provenance')
    assert_equal %w[prepared completed], journal.rows(@record.id).map { |row| row['event'] }
    assert_equal 0o600, File.stat(journal.path(@record.id)).mode & 0o777
  end
  test 'replay does not duplicate history or source writes' do
    apply
    evidence = @record.reload.year_evidence.deep_dup
    assert_equal 'already_applied', apply[:status]
    assert_equal evidence, @record.reload.year_evidence
    assert_equal 1, @record.year_history.size
    assert_equal 2, journal.rows(@record.id).size
  end
  test 'a manual summary change after proposal protects the work' do
    @record.update!(abstract: 'Nouvelle correction manuelle.')
    assert_equal 'protected_changed', apply[:status]
    assert_equal 'unknown', @record.reload.year_basis
    assert_not File.exist?(@directory)
  end
  test 'manual year changes and deletion of imported genres are never silently undone' do
    apply
    @record.reload.update!(year: 2021)
    @record.reload.gender_ids = []
    assert_equal 'protected_after_enrichment', apply[:status]
    assert_equal 2021, @record.reload.year
    assert_empty @record.genders
  end
  test 'preexisting year history is protected even with an unknown current basis' do
    @record.update!(year_history: [{ 'year' => 2020, 'basis' => 'unknown', 'evidence' => {} }])
    assert_equal 'protected_year_history', apply[:status]
    assert_equal 'unknown', @record.reload.year_basis
  end
  test 'a classification requiring more specific sources remains untouched while year progresses' do
    @entry['genre_review_required'] = true
    assert_equal 'applied', apply[:status]
    assert_equal 'first_release', @record.reload.year_basis
    assert_empty @record.genders
  end
  test 'a transaction failure leaves the work unchanged and permits retry of the same operation' do
    original = @record.abstract
    @service.stub(:verify_preserved!, ->(*) { raise ActiveRecord::RecordInvalid.new(@record) }) do
      assert_raises(ActiveRecord::RecordInvalid) { apply }
    end
    assert_equal 'unknown', @record.reload.year_basis
    assert_equal original, @record.abstract
    assert_empty @record.genders
    assert_equal 'applied', apply[:status]
  end
  test 'a committed update with a missing completion event is recovered without reapplying' do
    apply
    rows = journal.rows(@record.id)
    File.write(journal.path(@record.id), JSON.generate(rows.first) + "\n")
    assert_equal 'already_applied', apply[:status]
    assert_equal 1, @record.reload.year_history.size
    assert_equal 'completed', journal.rows(@record.id).last['event']
  end
  test 'a different operation preserves earlier enrichment even if a field was later cleared' do
    apply
    @record.reload.gender_ids = []
    other = CatalogEnrichment::FilmMetadataApplication.new(journal_directory: @directory, operation: 'different-operation')
    assert_equal 'protected_previous_operation', other.call(entry: @entry, apply: true)[:status]
    assert_empty @record.reload.genders
  end
  test 'invalid identity evidence or more than two proposed genres is refused before writes' do
    @entry['identity']['supported'] = false
    assert_raises(ArgumentError) { apply }
    @entry['identity']['supported'] = true
    @entry['proposal']['genres']['proposed'] = ['Action','Drame','Romance']
    assert_raises(ArgumentError) { apply }
    assert_equal 'unknown', @record.reload.year_basis
  end
  test 'symlink journals and non boolean apply flags are refused' do
    assert_raises(ArgumentError) { @service.call(entry: @entry, apply: 'true') }
    File.symlink(File.dirname(@directory), @directory)
    assert_raises(ArgumentError) { apply }
    assert_equal 'unknown', @record.reload.year_basis
  end
  test 'legacy validation errors are reported before saving any enrichment' do
    @record.update_columns(length_in_mn: 5)
    result = apply
    assert_equal 'blocked_validation', result[:status]
    assert result[:errors].key?(:length_in_mn)
    assert_equal 'unknown', @record.reload.year_basis
    assert_not File.exist?(@directory)
  end

end
