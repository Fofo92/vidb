require "test_helper"

class RecordTest < ActiveSupport::TestCase
  setup do
    @language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    create_record("Vu disponible 1", seen: true, available: true)
    create_record("Vu disponible 2", seen: true, available: true)
    create_record("Vu supprimé", seen: true, available: false)

    create_record("Non vu disponible", seen: false, available: true)
    create_record("Non vu supprimé 1", seen: false, available: false)
    create_record("Non vu supprimé 2", seen: false, available: false)
  end

  test "counts records by viewing and availability status" do
    assert_equal 3, Record.number_of_seen_records
    assert_equal 3, Record.number_of_unseen_records

    assert_equal 2, Record.number_of_seen_and_available_records
    assert_equal 1, Record.number_of_seen_and_removed_records
    assert_equal 1, Record.number_of_unseen_and_available_records
    assert_equal 2, Record.number_of_unseen_and_removed_records
  end

  private

  def create_record(title, seen:, available:)
    Record.create!(
      french_title: title,
      language_version: @language_version,
      is_seen: seen,
      is_available: available
    )
  end
end
