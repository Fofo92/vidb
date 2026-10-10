require "test_helper"

class RecordContainerSummaryTest < ActionView::TestCase
  test "audit overview separates containers and explains where gaps are counted" do
    audit = RecordMetadataAudit.new.call
    output = render partial: "pages/record_metadata_overview", locals: { audit: audit }
    assert_select "table", count: 2
    assert_select "th", text: "Saisons"
    assert_match "Le résumé d’une saison est facultatif", output
  end

  test "container year detail describes the synthesis instead of its legacy provenance" do
    language = LanguageVersion.create!(short_name: "VF", long_name: "Français année synthèse")
    series = Record.create!(french_title: "Série année synthèse", record_kind: "series", language_version: language)
    Record.create!(french_title: "Épisode année synthèse", record_kind: "episode", parent: series,
                   language_version: language, year: 2020, year_basis: "first_release")
    render partial: "records/year", locals: { record: series, detail: true }
    assert_select "span[data-record-year]", text: "2020"
    assert_select "small", text: "Années des vidéos connues"
  end
end
