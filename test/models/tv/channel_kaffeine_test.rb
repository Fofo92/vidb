require "test_helper"

module Tv
  class ChannelKaffeineTest < ActiveSupport::TestCase
    test "accepts an explicit Kaffeine channel name" do
      channel = build_channel(
        kaffeine_name: "F3 Paris Ile-de-France"
      )

      assert_predicate channel, :valid?
    end

    test "allows a channel without a Kaffeine mapping" do
      channel = build_channel(kaffeine_name: nil)

      assert_predicate channel, :valid?
    end

    test "requires Kaffeine channel names to be unique" do
      Channel.create!(
        display_name: "France 3",
        kaffeine_name: "F3 Paris Ile-de-France"
      )
      duplicate = build_channel(
        kaffeine_name: "F3 Paris Ile-de-France"
      )

      assert_not duplicate.valid?
      assert duplicate.errors.added?(
        :kaffeine_name,
        :taken,
        value: "F3 Paris Ile-de-France"
      )
    end

    private

    def build_channel(attributes)
      Channel.new(
        {
          display_name: "Chaîne de test"
        }.merge(attributes)
      )
    end
  end
end
