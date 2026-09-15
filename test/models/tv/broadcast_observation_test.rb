require "test_helper"

module Tv
  class BroadcastObservationTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      @guide_channel = source.guide_channels.create!(
        external_id: "C192.api.telerama.fr"
      )
      @starts_at = Time.utc(2026, 9, 14, 20, 0)
      @ends_at = Time.utc(2026, 9, 14, 21, 30)
    end

    test "requires its external guide channel" do
      observation = build_observation(guide_channel: nil)

      assert_not observation.valid?
      assert observation.errors[:guide_channel].any?
    end

    test "requires a hexadecimal SHA256 fingerprint" do
      [nil, "", "not-a-fingerprint", "a" * 63].each do |fingerprint|
        observation = build_observation(fingerprint: fingerprint)

        assert_not observation.valid?
        assert observation.errors[:fingerprint].any?
      end
    end

    test "defaults its fingerprint version to one" do
      observation = build_observation

      assert_equal 1, observation.fingerprint_version
    end

    test "requires its start and end times" do
      {
        starts_at: nil,
        ends_at: nil
      }.each do |attribute, value|
        observation = build_observation(attribute => value)

        assert_not observation.valid?
        assert observation.errors[attribute].any?
      end
    end

    test "requires its end to follow its start" do
      observation = build_observation(ends_at: @starts_at)

      assert_not observation.valid?
      assert observation.errors[:ends_at].any?
    end

    test "requires a fingerprint unique within its version" do
      build_observation.save!
      duplicate = build_observation

      assert_not duplicate.valid?
      assert duplicate.errors[:fingerprint].any?

      assert build_observation(
        fingerprint_version: 2
      ).valid?
    end

    private

    def build_observation(attributes = {})
      BroadcastObservation.new(
        {
          guide_channel: @guide_channel,
          fingerprint: "a" * 64,
          starts_at: @starts_at,
          ends_at: @ends_at
        }.merge(attributes)
      )
    end
  end
end
