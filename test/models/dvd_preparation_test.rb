require "test_helper"

class DvdPreparationTest < ActiveSupport::TestCase
  test "an unknown valid code can be saved without a work" do
    preparation = DvdPreparation.create!(ean: "5050582454376")
    assert_equal "Coffret à identifier", preparation.display_title
    assert_equal "À identifier", preparation.preparation_status
    assert_includes DvdPreparation.awaiting_identification, preparation
  end

  test "the database enforces one preparation per EAN" do
    first = DvdPreparation.create_or_find_by!(ean: "5050582454376")
    second = DvdPreparation.create_or_find_by!(ean: "5050582454376")
    assert_equal first.id, second.id
  end

  test "existing or subsequently attached editions are recognized without changing ownership" do
    preparation = DvdPreparation.create!(ean: "5050582454376")
    version = LanguageVersion.create!(short_name: "VF", long_name: "Version française")
    record = Record.create!(french_title: "Code Quantum", language_version: version, record_kind: "series")
    edition = DvdEdition.create!(ean: preparation.ean, record: record)
    assert_equal edition, preparation.reload.dvd_edition
    assert_equal "Identification confirmée", preparation.preparation_status
    assert_not_includes DvdPreparation.awaiting_identification, preparation
  end

  test "a manual title takes priority over preserved external proposals" do
    preparation = DvdPreparation.new(ean: "5050582454376", external_titles: ["Titre commercial"],
                                     provisional_title: "Titre provisoire")
    assert_equal "Titre provisoire", preparation.display_title
    preparation.provisional_title = nil
    assert_equal "Titre commercial", preparation.display_title
  end
end
