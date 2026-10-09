# frozen_string_literal: true

require 'test_helper'

class RecordYearsTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @record = Record.create!(french_title: 'Film', language_version: @language, year: 2020)
  end

  test 'legacy years remain unknown' do
    assert_equal 'unknown', @record.year_basis
    assert_equal '?', @record.year_basis_label
  end

  test 'qualification preserves previous year and is idempotent' do
    attributes = { year: 2021, year_basis: 'first_release', year_evidence: { 'provider' => 'tmdb' } }
    @record.update!(attributes)
    assert_equal 2020, @record.year_history.last.fetch('year')
    assert_equal 'unknown', @record.year_history.last.fetch('basis')
    assert_equal 'Diff.', @record.year_basis_label
    history = @record.year_history
    @record.update!(attributes)
    assert_equal history, @record.reload.year_history
  end

  test 'manual year edit clears stale qualification and retains its evidence' do
    @record.update!(year_basis: 'production', year_evidence: { 'source' => 'Générique' })
    @record.update!(year: 2019)
    assert_equal 'unknown', @record.year_basis
    assert_empty @record.year_evidence
    assert_equal 'production', @record.year_history.last.fetch('basis')
    assert_equal 'Générique', @record.year_history.last.fetch('evidence').fetch('source')
  end

  test 'parent range ignores parent year and detects mixed conventions' do
    series = Record.create!(french_title: 'Série', record_kind: 'series', language_version: @language, year: 1990)
    season = series.children.create!(french_title: 'Saison 01', record_kind: 'season', language_version: @language)
    first = season.children.create!(french_title: 'Premier', record_kind: 'episode', language_version: @language,
                                   year: 2020, year_basis: 'production')
    second = season.children.create!(french_title: 'Second', record_kind: 'episode', language_version: @language,
                                    year: 2021, year_basis: 'first_release')
    assert_equal '2020-2021', series.display_range_of_years
    assert_equal 'Mixte', series.year_basis_label
    first.update!(year_basis: 'first_release')
    assert_equal 'Diff.', season.year_basis_label
    assert_equal 'first_release', second.year_basis
  end
end
