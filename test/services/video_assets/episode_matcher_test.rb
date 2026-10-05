# frozen_string_literal: true

require 'test_helper'

module VideoAssets
  class EpisodeMatcherTest < ActiveSupport::TestCase
    setup do
      @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
      @series = record('Une série', rank: nil)
      @season = record('Saison 01', parent: @series, rank: 1)
      @episode = record('Pilote', parent: @season, rank: 1)
    end

    test 'matches a numbered episode within its series and season' do
      result = match('Une série (I - 01_02)/Saison 01 (01_02)/S01 E01 - Pilote.mkv')

      assert_equal 'episode_candidate', result[:status]
      assert_equal [@episode.id], result[:candidates].pluck(:record_id)
      assert_equal [@series.id, @season.id], result[:candidates].sole[:ancestors].pluck(:record_id)
    end

    test 'does not use a globally identical episode title' do
      result = match('Autre série/Saison 01/S01 E01 - Pilote.mkv')

      assert_equal 'container_unmatched', result[:reason]
      assert_empty result[:candidates]
    end

    test 'signals conflicting season numbers in the path' do
      result = match('Une série/Saison 02/S01 E01 - Pilote.mkv')

      assert_equal 'season_number_conflict', result[:reason]
    end

    test 'signals a title disagreement without accepting the rank alone' do
      result = match('Une série/Saison 01/S01 E01 - Autre titre.mkv')

      assert_equal 'episode_title_conflict', result[:status]
      assert_equal [@episode.id], result[:candidates].pluck(:record_id)
    end

    test 'keeps duplicate ranks ambiguous even if one title matches' do
      record('Autre titre', parent: @season, rank: 1)
      result = match('Une série/Saison 01/S01 E01 - Pilote.mkv')

      assert_equal 'ambiguous_episode', result[:status]
      assert_equal 2, result[:candidates].size
    end

    test 'recognizes legacy direct documentary episodes without inventing a season' do
      documentary = record('Un documentaire')
      episode = record('Premier volet', parent: documentary, rank: 1)
      result = match('Un documentaire (c - 5)/E01 - Premier volet.m4v')

      assert_equal 'episode_candidate', result[:status]
      assert_equal [episode.id], result[:candidates].pluck(:record_id)
    end

    test 'does not assume season one for legacy episodes under a series' do
      result = match('Une série/E01 - Pilote.mkv')

      assert_equal 'episode_unmatched', result[:reason]
      assert_empty result[:candidates]
    end

    test 'rejects a season whose title and rank contradict each other' do
      @season.update!(rank: 2)
      result = match('Une série/Saison 01/S01 E01 - Pilote.mkv')

      assert_equal 'season_unmatched', result[:reason]
    end

    test 'recognizes a language annotation in the directory count suffix' do
      result = match('Une série (I - VF)/Saison 01/S01 E01 - Pilote.mkv')

      assert_equal 'episode_candidate', result[:status]
    end

    test 'keeps differing parenthesized original titles as reviewable variants' do
      @episode.update!(original_title: 'Pilot')
      result = match('Une série/Saison 01/S01 E01 - Pilote (The Pilot).mkv')

      assert_equal 'episode_title_variant', result[:status]
      assert_equal 'parenthesized_title_difference', result[:title_evidence]
      assert_equal 'Pilote (The Pilot)', result[:observed_title]
    end

    test 'does not discard a substantive parenthesized part of a title' do
      @episode.update!(french_title: 'Pilote (Partie 1)')
      result = match('Une série/Saison 01/S01 E01 - Pilote (Partie 2).mkv')

      assert_equal 'episode_title_conflict', result[:status]
    end

    test 'diagnoses a matching container without children' do
      record('Un documentaire')
      result = match('Un documentaire/E01 - Pilote.mkv')

      assert_equal 'container_ineligible', result[:reason]
      assert_equal false, result[:container_candidates].sole[:has_children]
    end

    test 'diagnoses a container located below another record' do
      nested = record('Série imbriquée', parent: @series)
      record('Pilote', parent: nested, rank: 1)
      result = match('Série imbriquée/E01 - Pilote.mkv')

      assert_equal 'container_ineligible', result[:reason]
      assert_equal true, result[:container_candidates].sole[:non_root]
      assert_empty result[:candidates]
    end

    test 'retains a complete directory title before stripping count annotations' do
      root = record('Documentaire (VI)')
      episode = record('Pilote', parent: root, rank: 1)
      result = match('Documentaire (VI)/E01 - Pilote.mkv')

      assert_equal 'episode_candidate', result[:status]
      assert_equal [episode.id], result[:candidates].pluck(:record_id)
    end

    test 'recognizes season directories with surrounding whitespace' do
      result = match('Une série/ Saison 01 /S01 E01 - Pilote.mkv')

      assert_equal 'episode_candidate', result[:status]
      assert_equal [@episode.id], result[:candidates].pluck(:record_id)
    end

    private

    def record(title, parent: nil, rank: nil)
      Record.create!(french_title: title, language_version: @language, parent: parent, rank: rank)
    end

    def match(path)
      EpisodeMatcher.new(Record.all).match(
        relative_path: path, stem: File.basename(path, File.extname(path))
      )
    end
  end
end
