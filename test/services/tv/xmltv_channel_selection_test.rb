require "test_helper"

module Tv
  class XmltvChannelSelectionTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
    end

    test "uses the TNT catalogue without Canal Plus" do
      ids = XmltvChannelSelection.new(@source).call

      assert_includes ids, "TF1.fr"
      assert_not_includes ids, "CanalPlus.fr"
    end

    test "respects disabled channels independently of favorites" do
      Channel.create!(display_name: "TF1", logical_number: 1, enabled: false)
      Channel.create!(display_name: "France 2", logical_number: 2, favorite: false, enabled: true)
      ids = XmltvChannelSelection.new(@source).call

      assert_not_includes ids, "TF1.fr"
      assert_includes ids, "France2.fr"
    end

    test "includes an explicitly linked enabled channel outside the catalogue" do
      channel = Channel.create!(display_name: "Chaîne locale", enabled: true)
      @source.guide_channels.create!(external_id: "Local.fr", channel:)

      assert_includes XmltvChannelSelection.new(@source).call, "Local.fr"
    end
  end
end
