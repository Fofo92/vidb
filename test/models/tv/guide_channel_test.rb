require "test_helper"

module Tv
  class GuideChannelTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
    end

    test "requires a guide source" do
      guide_channel = build_guide_channel(guide_source: nil)

      assert_not guide_channel.valid?
      assert guide_channel.errors[:guide_source].any?
    end

    test "requires an external identifier" do
      guide_channel = build_guide_channel(external_id: nil)

      assert_not guide_channel.valid?
      assert guide_channel.errors[:external_id].any?
    end

    test "allows a channel mapping to remain absent" do
      guide_channel = build_guide_channel

      assert guide_channel.valid?
      assert_nil guide_channel.channel
    end

    test "maps optionally to a business channel" do
      channel = Channel.create!(display_name: "France 3")
      guide_channel = build_guide_channel(channel: channel)

      assert guide_channel.valid?
      assert_equal channel, guide_channel.channel
    end

    test "requires an external identifier unique within its source" do
      build_guide_channel.save!
      duplicate = build_guide_channel

      assert_not duplicate.valid?
      assert duplicate.errors[:external_id].any?

      other_source = GuideSource.create!(
        name: "other",
        display_name: "Autre source"
      )

      assert build_guide_channel(guide_source: other_source).valid?
    end

    test "defaults observed display names to an empty collection" do
      guide_channel = build_guide_channel

      assert_equal [], guide_channel.display_names
    end

    test "exposes its broadcast observations" do
      guide_channel = build_guide_channel
      guide_channel.save!
      observation = create_observation(guide_channel)

      assert_equal(
        [observation],
        guide_channel.broadcast_observations.to_a
      )
    end

    test "cannot be destroyed while an observation refers to it" do
      guide_channel = build_guide_channel
      guide_channel.save!
      create_observation(guide_channel)

      assert_not guide_channel.destroy
      assert guide_channel.errors[:base].any?
      assert GuideChannel.exists?(guide_channel.id)
    end

    private

    def create_observation(guide_channel)
      guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64,
        starts_at: Time.utc(2026, 9, 15, 20),
        ends_at: Time.utc(2026, 9, 15, 21)
      )
    end

    def build_guide_channel(attributes = {})
      GuideChannel.new(
        {
          guide_source: @source,
          external_id: "C192.api.telerama.fr"
        }.merge(attributes)
      )
    end
  end
end
