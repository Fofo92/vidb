require "test_helper"

module Tv
  class ChannelCatalogTest < ActiveSupport::TestCase
    test "lists the selected channels in logical number order" do
      entries = ChannelCatalog.entries

      assert_equal 26, entries.size
      assert_equal(
        [*1..25, 31],
        entries.map(&:logical_number)
      )
    end

    test "maps representative XMLTV identifiers explicitly" do
      expected_channels = {
        "TF1.fr" => [1, "TF1"],
        "France3.fr" => [3, "France 3"],
        "CStar.fr" => [17, "CStar"],
        "Numero23.fr" => [23, "RMC Story"],
        "LaChaineParlementaire.fr" => [8, "LCP"],
        "T18.fr" => [18, "T18"],
        "Cherie25.fr" => [25, "RMC Life"],
        "ParisPremiere.fr" => [31, "Paris Première"]
      }

      expected_channels.each do |external_id, expected|
        entry = ChannelCatalog.find(external_id)

        assert_equal expected.first, entry.logical_number
        assert_equal expected.last, entry.display_name
      end
    end

    test "excludes channels outside the selected catalogue" do
      excluded_ids = %w[
        CanalPlus.fr
        CanalPlusCinema.fr
        CanalPlusSport.fr
        PlanetePlus.fr
      ]

      excluded_ids.each do |external_id|
        assert_nil ChannelCatalog.find(external_id)
      end
    end
  end
end
