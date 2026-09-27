require "test_helper"

module Tv
  class ChannelCatalogSynchronizerTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "catalog_synchronizer_test",
        display_name: "Guide du test"
      )
      @tf1 = @source.guide_channels.create!(
        external_id: "TF1.fr",
        display_names: [
          { "value" => "TF1", "language" => "fr" }
        ]
      )
      @canal_plus = @source.guide_channels.create!(
        external_id: "CanalPlus.fr",
        display_names: [
          { "value" => "Canal+", "language" => "fr" }
        ]
      )
      @france_three = @source.guide_channels.create!(
        external_id: "France3.fr",
        display_names: [
          { "value" => "France 3", "language" => "fr" }
        ]
      )
    end

    test "maps selected external channels to business channels" do
      ChannelCatalogSynchronizer.new(@source).call

      channel = Channel.find_by!(logical_number: 1)

      assert_equal "TF1", channel.display_name
      assert_equal channel, @tf1.reload.channel
      france_three = Channel.find_by!(logical_number: 3)

      assert_equal "France 3", france_three.display_name
      assert_equal(
        "F3 Paris Ile-de-France",
        france_three.kaffeine_name
      )
      assert_equal france_three, @france_three.reload.channel
      assert_nil @canal_plus.reload.channel
    end

    test "can be applied repeatedly without duplicating channels" do
      synchronizer = ChannelCatalogSynchronizer.new(@source)
      synchronizer.call

      assert_no_difference("Channel.count") do
        synchronizer.call
      end

      assert_equal 1, @tf1.reload.channel.logical_number
    end
  end
end
