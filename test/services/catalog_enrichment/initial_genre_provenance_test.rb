# frozen_string_literal: true

require 'test_helper'
require 'tmpdir'
require 'fileutils'

class InitialGenreProvenanceTest < ActiveSupport::TestCase
  self.use_transactional_tests = false

  setup do
    @directory = Dir.mktmpdir('vidb-initial-genres-', '/tmp')
    @language = LanguageVersion.create!(short_name: 'IGP_TEST', long_name: 'Initial genre protection test')
    @genre = Gender.create!(name: 'IGP_TEST_GENRE')
    @record = Record.create!(french_title: 'Initial genre protection', year: 2000,
                             record_kind: 'standalone_video', language_version: @language)
    @service = CatalogEnrichment::FilmMetadataApplication.new(
      journal_directory: File.join(@directory, 'journal'), operation: 'initial-genre-protection-test'
    )
  end

  teardown do
    @record&.destroy! if @record&.persisted?
    @genre&.destroy! if @genre&.persisted?
    @language&.destroy! if @language&.persisted?
    FileUtils.remove_entry(@directory) if @directory && File.directory?(@directory)
  end

  def entry
    local = @record.attributes.slice('french_title', 'original_title', 'year', 'year_basis', 'year_evidence', 'abstract')
    local['original_title'] = local['original_title'].to_s
    local.merge!('record_id' => @record.id, 'genres' => @record.genders.map(&:name).sort)
    { 'status' => 'candidate', 'identity' => { 'tmdb_id' => 42, 'supported' => true }, 'local' => local,
      'proposal' => { 'source' => { 'provider' => 'tmdb', 'external_id' => 42 },
                      'genres' => { 'status' => 'candidate', 'proposed' => [@genre.name] },
                      'year' => { 'status' => 'candidate', 'current' => 2000, 'proposed' => 2000,
                                  'date' => '2000-01-01', 'year_basis' => 'first_release',
                                  'reference' => { 'policy' => 'first_public_release_v1',
                                                   'selected' => { 'date' => '2000-01-01', 'type' => 1 } } } } }
  end

  test 'initial external genre fill records its actual origin' do
    assert_equal 'applied', @service.call(entry: entry, apply: true)[:status]
    assert_equal 'initial_external_enrichment', @record.reload.genre_provenance['origin']
    assert_equal [@genre.name], @record.genre_provenance['genres']
    assert_equal [], @record.genre_provenance['previous_genres']
  end

  test 'manually cleared genres stay empty while year qualification progresses' do
    @record.genders = [@genre]
    @record.genders.clear
    receipt = @record.reload.genre_provenance.deep_dup
    assert_equal 'applied', @service.call(entry: entry, apply: true)[:status]
    assert_equal 'first_release', @record.reload.year_basis
    assert_empty @record.genders
    assert_equal receipt, @record.genre_provenance
  end

  test 'a preview after manual deletion performs no provenance write' do
    @record.genders = [@genre]
    @record.genders.clear
    receipt = @record.reload.genre_provenance.deep_dup
    assert_equal 'ready', @service.call(entry: entry)[:status]
    assert_equal receipt, @record.reload.genre_provenance
    assert_empty @record.genders
    assert_not File.exist?(File.join(@directory, 'journal'))
  end
end
