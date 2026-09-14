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
  end
end
