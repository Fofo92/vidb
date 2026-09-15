require "test_helper"

module Tv
  class GuideImportChannelConsistencyTest <
      ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      guide_channel = source.guide_channels.create!(
        external_id: "C192.api.telerama.fr"
      )
      guide_import = source.guide_imports.create!(
        document_sha256: "a" * 64,
        document_byte_size: 1_024
      )
      @coverage = GuideImportChannel.new(
        guide_import: guide_import,
        guide_channel: guide_channel
      )
      @starts_at = Time.utc(2026, 9, 15, 20)
      @ends_at = Time.utc(2026, 9, 16, 2)
    end

    test "requires a time range when programmes are present" do
      %i[first_starts_at last_ends_at].each do |field|
        coverage = @coverage.dup
        coverage.assign_attributes(valid_coverage_attributes)
        coverage.public_send("#{field}=", nil)

        assert_not coverage.valid?
        assert coverage.errors[field].any?
      end
    end

    test "requires no time range when no programme is present" do
      @coverage.assign_attributes(
        first_starts_at: @starts_at,
        last_ends_at: @ends_at
      )

      assert_not @coverage.valid?
      assert @coverage.errors[:base].any?
    end

    test "requires the coverage end to follow its start" do
      @coverage.assign_attributes(
        valid_coverage_attributes.merge(last_ends_at: @starts_at)
      )

      assert_not @coverage.valid?
      assert @coverage.errors[:last_ends_at].any?
    end

    test "requires JSON collections and consistent gap totals" do
      {
        display_names: {},
        gaps: {}
      }.each do |field, value|
        coverage = @coverage.dup
        coverage.public_send("#{field}=", value)

        assert_not coverage.valid?
        assert coverage.errors[field].any?
      end

      inconsistent = @coverage.dup
      inconsistent.assign_attributes(
        valid_coverage_attributes.merge(
          gap_count: 2,
          total_gap_duration_seconds: 900,
          gaps: [gap_attributes]
        )
      )

      assert_not inconsistent.valid?
      assert inconsistent.errors[:gaps].any?
    end

    test "rejects a gap duration total inconsistent with its details" do
      @coverage.assign_attributes(
        valid_coverage_attributes.merge(
          gap_count: 1,
          total_gap_duration_seconds: 899,
          gaps: [gap_attributes]
        )
      )

      assert_not @coverage.valid?
      assert @coverage.errors[:gaps].any?
    end

    test "rejects an invalid gap duration" do
      @coverage.assign_attributes(
        valid_coverage_attributes.merge(
          gap_count: 1,
          total_gap_duration_seconds: 0,
          gaps: [
            gap_attributes.merge("duration_seconds" => -1)
          ]
        )
      )

      assert_not @coverage.valid?
      assert @coverage.errors[:gaps].any?
    end

    private

    def valid_coverage_attributes
      {
        programme_count: 12,
        first_starts_at: @starts_at,
        last_ends_at: @ends_at
      }
    end

    def gap_attributes
      {
        "starts_at" => "2026-09-15T22:00:00Z",
        "ends_at" => "2026-09-15T22:15:00Z",
        "duration_seconds" => 900
      }
    end
  end
end
