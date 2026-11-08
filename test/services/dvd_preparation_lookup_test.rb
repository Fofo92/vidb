require "test_helper"

class DvdPreparationLookupTest < ActiveSupport::TestCase
  test "an empty response is preserved as no result rather than an outage" do
    preparation = DvdPreparation.create!(ean: "5050582454376")
    client = Object.new
    client.define_singleton_method(:call) { |_ean| [] }
    DvdPreparationLookup.new(client: client).call(preparation)
    assert_equal "not_found", preparation.reload.lookup_status
    assert_not_nil preparation.lookup_checked_at
  end

  test "an outage preserves the previously retrieved titles and manual draft" do
    preparation = DvdPreparation.create!(ean: "5050582454376", external_titles: ["Titre précédent"], notes: "Ma note")
    client = Object.new
    def client.call(_ean)
      raise DvdBarcodeLookup::Error
    end
    DvdPreparationLookup.new(client: client).call(preparation)
    assert_equal "unavailable", preparation.reload.lookup_status
    assert_equal ["Titre précédent"], preparation.external_titles
    assert_equal "Ma note", preparation.notes
  end
end
