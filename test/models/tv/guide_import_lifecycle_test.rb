require "test_helper"

module Tv
  class GuideImportLifecycleTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      @started_at = Time.current
    end

    test "rejects a running import with a completion time" do
      guide_import = build_import(finished_at: Time.current)

      assert_not guide_import.valid?
      assert guide_import.errors[:finished_at].any?
    end

    test "requires a completion time for a finished import" do
      %w[succeeded failed].each do |status|
        guide_import = build_import(
          status: status,
          finished_at: nil
        )

        assert_not guide_import.valid?
        assert guide_import.errors[:finished_at].any?
      end
    end

    test "requires an error message only for a failed import" do
      failed_import = build_import(
        status: "failed",
        error_message: nil
      )
      succeeded_import = build_import(
        status: "succeeded",
        error_message: "Erreur résiduelle"
      )

      assert_not failed_import.valid?
      assert failed_import.errors[:error_message].any?
      assert_not succeeded_import.valid?
      assert succeeded_import.errors[:error_message].any?
    end

    test "rejects a completion time before its start" do
      started_at = Time.current
      guide_import = build_import(
        status: "succeeded",
        started_at: started_at,
        finished_at: started_at - 1.second
      )

      assert_not guide_import.valid?
      assert guide_import.errors[:finished_at].any?
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
