# frozen_string_literal: true

require 'test_helper'

class BroadcastPartComparisonTest < ActiveSupport::TestCase
  test 'parses explicit parts and does not infer parts from episode numbers alone' do
    parsed = CatalogEnrichment::BroadcastPartName.call(entry(2, 2))
    assert_equal 2, parsed[:local_number]
    assert_equal 2, parsed[:part]
    assert_equal 'Sans les yeux', parsed[:title]
    assert_nil CatalogEnrichment::BroadcastPartName.call(entry(2, 2).merge(stem: 'S01 E02 - Sans les yeux'))
  end

  test 'pairs by titles and flags multiple copies without creating records' do
    setup_records
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      report = compare([entry(1, 1), entry(2, 2), entry(2, 2, extension: 'm4v')])
      proposal = report[:proposals].first
      assert_equal 'pair_proposal', proposal[:status]
      assert_equal [@episode.id], proposal[:record_ids]
      assert proposal[:multiple_copies]
      assert_equal 3, proposal[:parts].size
    end
  end

  test 'incomplete and contradictory pairs cannot become accepted proposals' do
    setup_records
    assert_equal 'incomplete_pair', compare([entry(1, 1)])[:proposals].first[:status]
    assert_equal 'numbering_review', compare([entry(1, 1), entry(4, 2)])[:proposals].first[:status]
    @episode.update!(rank: 2)
    assert_equal 'catalogue_number_review', compare([entry(1, 1), entry(2, 2)])[:proposals].first[:status]
  end

  test 'original title supports a French variant but missing identity stays blocked' do
    setup_records
    @episode.update!(french_title: 'Titre différent')
    proposal = compare([entry(1, 1), entry(2, 2)])[:proposals].first
    assert_equal 'pair_proposal', proposal[:status]
    assert_equal :french_title, proposal[:title_differences].first[:field]
    @episode.update!(original_title: 'Autre titre')
    assert_equal 'identity_review', compare([entry(1, 1), entry(2, 2)])[:proposals].first[:status]
  end

  private

  def setup_records
    language = LanguageVersion.create!(short_name: 'IN', long_name: 'Indéterminée')
    @root = Record.create!(french_title: 'Série test', language_version: language)
    season = Record.create!(french_title: 'Saison 01', rank: 1, parent: @root, language_version: language)
    @episode = Record.create!(french_title: 'Sans les yeux', original_title: 'Senza occhi', rank: 1,
                              parent: season, language_version: language)
  end

  def entry(number, part, extension: 'mkv')
    stem = "S01 E#{number.to_s.rjust(2, '0')} - Sans les yeux, partie #{part} (Senza occhi)_vf"
    { stem: stem, path: "/videos/Test/Saison 01/#{stem}.#{extension}", size: 100 }
  end

  def compare(entries)
    CatalogEnrichment::BroadcastPartComparison.new(entries: entries, root: @root, directory: '/videos/Test').call
  end
end
