require "test_helper"

class RecordMetadataAuditTest < ActiveSupport::TestCase
  test "counts a record once while counting each missing field separately" do
    unknown = LanguageVersion.find_or_create_by!(short_name: "?") { |version| version.long_name = "Inconnue" }
    record = Record.create!(french_title: "Audit incomplet", record_kind: "undetermined", language_version: unknown)
    result = RecordMetadataAudit.new.call
    row = result[:records].find { |item| item[:id] == record.id }
    assert_equal %i[placement country genres year abstract language medium], row[:missing]
    assert_equal result[:records].count { |item| item[:missing].any? }, result[:incomplete]
    assert_equal result[:records].size, result[:to_work]
  end

  test "unqualified present copies do not inherit the record language or support" do
    vf = LanguageVersion.create!(short_name: "VF", long_name: "Français audit")
    hd = Medium.create!(short_name: "HD", long_name: "HD audit")
    record = Record.create!(french_title: "Audit copie", record_kind: "standalone_video",
                            language_version: vf, media: [hd], year: 2020, year_basis: "production")
    VideoAsset.create!(record: record, status: "present", last_known_path: "/videos/audit.mkv")
    row = RecordMetadataAudit.new.call[:records].find { |item| item[:id] == record.id }
    assert_includes row[:missing], :language
    assert_includes row[:missing], :medium
  end
end
