require "test_helper"

module Tv
  class BroadcastObservationMetadataTest < ActiveSupport::TestCase
    METADATA_FIELDS = %i[
      titles
      subtitles
      descriptions
      categories
      episode_numbers
    ].freeze

    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      guide_channel = source.guide_channels.create!(
        external_id: "C192.api.telerama.fr"
      )
      @observation = BroadcastObservation.new(
        guide_channel: guide_channel,
        fingerprint: "a" * 64,
        starts_at: Time.utc(2026, 9, 15, 20),
        ends_at: Time.utc(2026, 9, 15, 21)
      )
    end

    test "defaults structured metadata to empty collections" do
      METADATA_FIELDS.each do |field|
        assert_equal [], @observation.public_send(field)
      end
    end

    test "stores raw times and structured XMLTV metadata" do
      @observation.assign_attributes(
        source_start: "20260915200000 +0200",
        source_stop: "20260915210000 +0200",
        titles: [
          { "value" => "Titre français", "language" => "fr" }
        ],
        subtitles: [
          { "value" => "Titre de l’épisode", "language" => "fr" }
        ],
        descriptions: [
          { "value" => "Résumé du programme", "language" => "fr" }
        ],
        categories: [
          { "value" => "Série", "language" => "fr" }
        ],
        episode_numbers: [
          { "value" => "2.2.", "system" => "xmltv_ns" }
        ]
      )

      assert @observation.valid?
      assert_equal "20260915200000 +0200", @observation.source_start
      assert_equal "Titre français",
                   @observation.titles.first["value"]
      assert_equal "xmltv_ns",
                   @observation.episode_numbers.first["system"]
    end

    test "requires structured metadata fields to be arrays" do
      METADATA_FIELDS.each do |field|
        observation = @observation.dup
        observation.public_send("#{field}=", {})

        assert_not observation.valid?
        assert observation.errors[field].any?
      end
    end

    test "requires every metadata entry to contain a value" do
      METADATA_FIELDS.each do |field|
        observation = @observation.dup
        observation.public_send(
          "#{field}=",
          [{ "language" => "fr" }]
        )

        assert_not observation.valid?
        assert observation.errors[field].any?
      end
    end
  end
end
