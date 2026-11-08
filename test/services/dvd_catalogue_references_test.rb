require "test_helper"

class DvdCatalogueReferencesTest < ActiveSupport::TestCase
  setup do
    @references = Object.new
    @references.define_singleton_method(:genres) do |candidate|
      ids = candidate.fetch("genres_text").split(",").map(&:strip).filter_map do |name|
        { "Drame" => 1, "Comédie" => 2, "Policier" => 3 }[name]
      end
      ids if ids.size <= 2
    end
    @references.define_singleton_method(:countries) { |candidate| candidate.fetch("country_codes", []) }
  end

  test "film references survive prefill and genres are distinct and limited to two" do
    params = ActionController::Parameters.new(dvd_references: {
      genres_text: "Drame, Comédie, Policier, Drame", country_codes: ["FR", "BE"]
    })
    result = DvdCatalogueReferences.new(references: @references).call(params)
    assert_equal [1, 2], result.fetch(:gender_ids)
    assert_equal ["FR", "BE"], result.fetch(:country_ids)
  end

  test "selected series uses its details and production countries" do
    client = Object.new
    client.define_singleton_method(:get) do |path|
      raise "wrong series" unless path == "tv/4018"

      { "id" => 4018, "genres" => [{ "name" => "Drame" }],
        "production_countries" => [{ "iso_3166_1" => "US" }], "origin_country" => ["GB"] }
    end
    params = ActionController::Parameters.new(dvd_references: { tmdb_series_id: "4018" })
    result = DvdCatalogueReferences.new(tmdb: client, references: @references).call(params)
    assert_equal [1], result.fetch(:gender_ids)
    assert_equal ["US"], result.fetch(:country_ids)
  end

  test "missing metadata leaves associations empty" do
    result = DvdCatalogueReferences.new(references: @references).call(ActionController::Parameters.new)
    assert_empty result.fetch(:gender_ids)
    assert_empty result.fetch(:country_ids)
  end
end
