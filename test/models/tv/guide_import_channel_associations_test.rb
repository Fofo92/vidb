require "test_helper"

module Tv
  class GuideImportChannelAssociationsTest <
      ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xmltv_test",
        display_name: "XMLTV test"
      )
      @guide_import = GuideImport.create!(
        guide_source: @source,
        document_sha256: "a" * 64,
        document_byte_size: 100
      )
      @guide_channel = GuideChannel.create!(
        guide_source: @source,
        external_id: "tf1.test"
      )
      @coverage = GuideImportChannel.create!(
        guide_import: @guide_import,
        guide_channel: @guide_channel
      )
    end

    test "exposes channel coverage from both owners" do
      assert_includes(
        @guide_import.guide_import_channels,
        @coverage
      )
      assert_includes(
        @guide_channel.guide_import_channels,
        @coverage
      )
    end

    test "protects owners while channel coverage exists" do
      assert_not @guide_import.destroy
      assert @guide_import.errors[:base].any?

      assert_not @guide_channel.destroy
      assert @guide_channel.errors[:base].any?

      assert GuideImportChannel.exists?(@coverage.id)
    end
  end
end
