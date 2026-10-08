# frozen_string_literal: true

require 'test_helper'

module VideoAssets
  class EpisodeNumberTest < ActiveSupport::TestCase
    test 'catalogue prefix never becomes the episode number' do
      number = EpisodeNumber.call('02 - S00 E01 - Rançon pour un homme mort').fetch(:number)
      assert_equal '00', number[:season]
      assert_equal '01', number[:episode]
      assert_equal ' - Rançon pour un homme mort', number.string[number.end(0)..]
    end

    test 'recognizes explicit numbering after a series title' do
      number = EpisodeNumber.call('Code quantum S03 E03 - Au nom du père').fetch(:number)
      assert_equal '03', number[:season]
      assert_equal '03', number[:episode]
    end

    test 'recognizes compact explicit numbering among dot separators' do
      number = EpisodeNumber.call('Breaking.Bad.S03E01.No.Mas.VOSTFR').fetch(:number)
      assert_equal '03', number[:season]
      assert_equal '01', number[:episode]
    end

    test 'preserves direct documentary numbering without inventing a season' do
      number = EpisodeNumber.call('E02 - Le titre').fetch(:number)
      assert_nil number[:season]
      assert_equal '02', number[:episode]
    end

    test 'conflicting or repeated explicit pairs stay blocked' do
      assert_equal 'episode_number_ambiguous', EpisodeNumber.call('S01 E01 et S01 E02')[:reason]
      assert_equal 'episode_number_ambiguous', EpisodeNumber.call('S01 E01 - S01 E01')[:reason]
    end

    test 'bare catalogue indices are not episode evidence' do
      assert_equal 'episode_number_unrecognized', EpisodeNumber.call('02 - Le titre')[:reason]
      assert_equal 'episode_number_unrecognized', EpisodeNumber.call('FilmXS01E02')[:reason]
    end
  end
end
