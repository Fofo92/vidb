require "test_helper"

module VideoAssets
  class DisplaySummaryTest < ActiveSupport::TestCase
    test "compact values keep detail provenance out of summary tables" do
      vf = LanguageVersion.create!(short_name: "VF", long_name: "Français synthèse")
      record = Record.create!(french_title: "Synthèse", record_kind: "standalone_video",
                              language_version: vf, length_in_mn: 45)
      summary = DisplaySummary.new(record: record, records: [record], assets: [])
      assert_equal "VF", summary.summary_languages
      assert_equal "—", summary.summary_supports
      assert_equal "00h45", summary.summary_duration
      assert_includes summary.languages, "catalogue"
    end
  end
end
