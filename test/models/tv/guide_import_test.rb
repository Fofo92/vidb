require "test_helper"

module Tv
  class GuideImportTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      @started_at = Time.current
    end

    test "requires its guide source" do
      guide_import = build_import(guide_source: nil)

      assert_not guide_import.valid?
      assert guide_import.errors[:guide_source].any?
    end

    test "requires a hexadecimal SHA256 document digest" do
      [nil, "", "not-a-digest", "a" * 63].each do |digest|
        guide_import = build_import(document_sha256: digest)

        assert_not guide_import.valid?
        assert guide_import.errors[:document_sha256].any?
      end
    end

    test "requires a nonnegative document byte size" do
      [nil, -1].each do |byte_size|
        guide_import = build_import(document_byte_size: byte_size)

        assert_not guide_import.valid?
        assert guide_import.errors[:document_byte_size].any?
      end

      assert build_import(document_byte_size: 0).valid?
    end

    test "defaults to running" do
      guide_import = build_import

      assert guide_import.status_running?
    end

    test "accepts the supported states" do
      %w[running succeeded failed].each do |status|
        guide_import = build_import(status: status)

        assert guide_import.valid?
        assert guide_import.public_send("status_#{status}?")
      end
    end

    test "rejects an unsupported state" do
      assert_raises(ArgumentError) do
        build_import(status: "unknown")
      end
    end

    test "allows repeated failed attempts for the same document" do
      build_import(status: "failed").save!
      retry_import = build_import(status: "failed")

      assert retry_import.valid?
    end

    test "allows only one successful import of a document per source" do
      build_import(status: "succeeded").save!
      duplicate = build_import(status: "succeeded")

      assert_not duplicate.valid?
      assert duplicate.errors[:document_sha256].any?

      other_source = GuideSource.create!(
        name: "other",
        display_name: "Autre source"
      )

      assert build_import(
        guide_source: other_source,
        status: "succeeded"
      ).valid?
    end

    private

    def build_import(attributes = {})
      GuideImport.new(
        {
          guide_source: @source,
          document_sha256: "a" * 64,
          document_byte_size: 1_024,
          started_at: @started_at
        }.merge(status_attributes(attributes[:status]))
         .merge(attributes)
      )
    end

    def status_attributes(status)
      case status
      when "succeeded"
        { finished_at: @started_at + 1.second }
      when "failed"
        { finished_at: @started_at + 1.second, error_message: "Import impossible" }
      else
        {}
      end
    end
  end
end
