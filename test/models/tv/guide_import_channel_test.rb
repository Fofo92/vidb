require "test_helper"

module Tv
  class GuideImportChannelTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      @guide_channel = source.guide_channels.create!(
        external_id: "C192.api.telerama.fr"
      )
      @guide_import = source.guide_imports.create!(
        document_sha256: "a" * 64,
        document_byte_size: 1_024
      )
    end

    test "requires an import and an external channel" do
      {
        guide_import: nil,
        guide_channel: nil
      }.each do |association, value|
        coverage = build_coverage(association => value)

        assert_not coverage.valid?
        assert coverage.errors[association].any?
      end
    end

    test "links a channel only once within an import" do
      build_coverage.save!
      duplicate = build_coverage

      assert_not duplicate.valid?
      assert duplicate.errors[:guide_channel].any?
    end

    test "defaults coverage results to empty values" do
      coverage = build_coverage

      assert_equal [], coverage.display_names
      assert_equal 0, coverage.programme_count
      assert_equal 0, coverage.gap_count
      assert_equal 0, coverage.total_gap_duration_seconds
      assert_equal [], coverage.gaps
      assert_nil coverage.first_starts_at
      assert_nil coverage.last_ends_at
    end

    test "stores a measured channel coverage" do
      first_starts_at = Time.utc(2026, 9, 15, 20)
      last_ends_at = Time.utc(2026, 9, 16, 2)

      coverage = build_coverage(
        display_names: [
          { "value" => "France 3", "language" => "fr" }
        ],
        programme_count: 12,
        first_starts_at: first_starts_at,
        last_ends_at: last_ends_at,
        gap_count: 1,
        total_gap_duration_seconds: 900,
        gaps: [
          {
            "starts_at" => "2026-09-15T22:00:00Z",
            "ends_at" => "2026-09-15T22:15:00Z",
            "duration_seconds" => 900
          }
        ]
      )

      assert coverage.valid?
      assert_equal 12, coverage.programme_count
      assert_equal 1, coverage.gap_count
      assert_equal 900, coverage.total_gap_duration_seconds
    end

    test "rejects negative coverage counters" do
      %i[
        programme_count
        gap_count
        total_gap_duration_seconds
      ].each do |counter|
        coverage = build_coverage(counter => -1)

        assert_not coverage.valid?
        assert coverage.errors[counter].any?
      end
    end

    private

    def build_coverage(attributes = {})
      GuideImportChannel.new(
        {
          guide_import: @guide_import,
          guide_channel: @guide_channel
        }.merge(attributes)
      )
    end
  end
end
