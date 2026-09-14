require "test_helper"

module Tv
  class GuideImportDetailsTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
    end

    test "starts when it is created" do
      guide_import = build_import
      guide_import.save!

      assert guide_import.started_at
      assert_nil guide_import.finished_at
    end

    test "defaults import results to empty values" do
      guide_import = build_import

      assert_equal({}, guide_import.source_metadata)
      assert_equal 0, guide_import.channel_count
      assert_equal 0, guide_import.source_programme_count
      assert_equal 0, guide_import.programme_count
      assert_equal 0, guide_import.duplicate_programme_count
      assert_nil guide_import.error_message
    end

    test "stores source metadata and import results" do
      started_at = Time.current

      guide_import = build_import(
        status: "succeeded",
        started_at: started_at,
        finished_at: started_at + 1.second,
        source_metadata: {
          "source_name" => "XML TV Fr"
        },
        channel_count: 30,
        source_programme_count: 8_078,
        programme_count: 8_074,
        duplicate_programme_count: 4
      )

      assert guide_import.valid?
      assert_equal(
        "XML TV Fr",
        guide_import.source_metadata["source_name"]
      )
      assert_equal 8_078, guide_import.source_programme_count
      assert_equal 8_074, guide_import.programme_count
      assert_equal 4, guide_import.duplicate_programme_count
    end

    test "rejects negative import counters" do
      counter_names = %i[
        channel_count
        source_programme_count
        programme_count
        duplicate_programme_count
      ]

      counter_names.each do |counter_name|
        guide_import = build_import(counter_name => -1)

        assert_not guide_import.valid?
        assert guide_import.errors[counter_name].any?
      end
    end

    private

    def build_import(attributes = {})
      GuideImport.new(
        {
          guide_source: @source,
          document_sha256: "a" * 64,
          document_byte_size: 1_024
        }.merge(attributes)
      )
    end
  end
end
