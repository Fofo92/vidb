require "test_helper"

module Tv
  class ChannelTest < ActiveSupport::TestCase
    test "requires a display name" do
      channel = Channel.new(display_name: nil)

      assert_not channel.valid?
      assert channel.errors[:display_name].any?
    end

    test "defaults to enabled" do
      channel = Channel.new(display_name: "France 3")

      assert channel.enabled?
    end

    test "accepts a disabled channel" do
      channel = Channel.new(
        display_name: "Chaîne arrêtée",
        enabled: false
      )

      assert channel.valid?
      assert_not channel.enabled?
    end

    test "exposes its external guide channel mappings" do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      channel = Channel.create!(display_name: "France 3")

      guide_channel = source.guide_channels.create!(
        external_id: "C192.api.telerama.fr",
        channel: channel
      )

      assert_equal [guide_channel], channel.guide_channels.to_a
    end

    test "cannot be destroyed while an external channel maps to it" do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      channel = Channel.create!(display_name: "France 3")
      source.guide_channels.create!(
        external_id: "C192.api.telerama.fr",
        channel: channel
      )

      assert_not channel.destroy
      assert channel.errors[:base].any?
      assert Channel.exists?(channel.id)
    end
  end
end
