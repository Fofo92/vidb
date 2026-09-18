require "test_helper"

module Tv
  class GuideSourceCurrentImportTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "current_guide_test",
        display_name: "Guide de test"
      )
      @started_at = Time.utc(2026, 9, 18, 10)
    end

    test "returns nil without a successful import" do
      create_import("a", "failed", @started_at)

      assert_nil @source.latest_successful_import
    end

    test "ignores newer failed and running imports" do
      create_import("a", "succeeded", @started_at)
      latest = create_import(
        "b", "succeeded", @started_at + 1.hour
      )
      create_import("c", "failed", @started_at + 2.hours)
      create_import("d", "running", @started_at + 3.hours)

      assert_equal latest, @source.latest_successful_import
    end

    private

    def create_import(digest_character, status, started_at)
      @source.guide_imports.create!(
        document_sha256: digest_character * 64,
        document_byte_size: 100,
        status: status,
        started_at: started_at,
        finished_at: status == "running" ? nil : started_at + 1.minute,
        error_message: status == "failed" ? "Échec de test" : nil
      )
    end
  end
end
