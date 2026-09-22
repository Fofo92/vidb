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

    test "accepts a positive logical channel number" do
      channel = Channel.new(
        display_name: "France 2",
        logical_number: 2
      )

      assert channel.valid?
      assert_equal 2, channel.logical_number
    end

    test "rejects a nonpositive or noninteger logical number" do
      [0, -1, 1.5].each do |logical_number|
        channel = Channel.new(
          display_name: "Chaîne invalide",
          logical_number: logical_number
        )

        assert_not channel.valid?, "Accepted #{logical_number.inspect}"
        assert channel.errors[:logical_number].any?
      end
    end

    test "requires a unique logical number when present" do
      Channel.create!(
        display_name: "France 2",
        logical_number: 2
      )
      duplicate = Channel.new(
        display_name: "Autre chaîne",
        logical_number: 2
      )

      assert_not duplicate.valid?
      assert duplicate.errors[:logical_number].any?
    end
  end
end
