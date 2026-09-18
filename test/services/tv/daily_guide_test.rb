require "test_helper"

module Tv
  class DailyGuideTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "daily_guide_test",
        display_name: "Guide journalier de test"
      )
      @date = Date.new(2026, 9, 18)
    end

    test "returns no programmes without a successful import" do
      programmes = DailyGuide.new(
        guide_source: @source,
        date: @date
      ).call

      assert_empty programmes
    end

    test "returns programmes overlapping the Paris calendar day" do
      guide_import = create_successful_import
      channel = @source.guide_channels.create!(external_id: "test.fr")

      add_programme(guide_import, channel, 1,
                    "2026-09-17T23:00:00+02:00", "2026-09-18T00:00:00+02:00")
      overnight = add_programme(guide_import, channel, 2,
                                "2026-09-17T23:30:00+02:00", "2026-09-18T00:30:00+02:00")
      daytime = add_programme(guide_import, channel, 3,
                              "2026-09-18T12:00:00+02:00", "2026-09-18T13:00:00+02:00")
      late = add_programme(guide_import, channel, 4,
                           "2026-09-18T23:30:00+02:00", "2026-09-19T00:30:00+02:00")
      add_programme(guide_import, channel, 5,
                    "2026-09-19T00:00:00+02:00", "2026-09-19T01:00:00+02:00")

      programmes = DailyGuide.new(guide_source: @source, date: @date).call

      assert_equal [overnight, daytime, late], programmes.to_a
    end

    test "includes the final hour of a 25-hour Paris day" do
      guide_import = create_successful_import
      channel = @source.guide_channels.create!(external_id: "test.fr")

      late = add_programme(
        guide_import, channel, 1,
        "2026-10-25T23:30:00+01:00",
        "2026-10-26T00:30:00+01:00"
      )
      add_programme(
        guide_import, channel, 2,
        "2026-10-26T00:00:00+01:00",
        "2026-10-26T01:00:00+01:00"
      )

      programmes = DailyGuide.new(
        guide_source: @source,
        date: Date.new(2026, 10, 25)
      ).call

      assert_equal [late], programmes.to_a
    end

    private

    def create_successful_import
      @source.guide_imports.create!(
        document_sha256: "a" * 64,
        document_byte_size: 100,
        status: "succeeded",
        started_at: Time.utc(2026, 9, 18, 8),
        finished_at: Time.utc(2026, 9, 18, 8, 1)
      )
    end

    def add_programme(guide_import, channel, number, starts_at, ends_at)
      observation = BroadcastObservation.create!(
        guide_channel: channel,
        fingerprint: format("%064x", number),
        starts_at: starts_at,
        ends_at: ends_at
      )
      guide_import.guide_import_observations.create!(
        broadcast_observation: observation
      )
      observation
    end
  end
end
