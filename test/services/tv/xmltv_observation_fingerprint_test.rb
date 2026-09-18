require "test_helper"

module Tv
  class XmltvObservationFingerprintTest <
      ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      @programme = XmltvReader.new(
        file_fixture("tv/minimal_guide.xml")
      ).call.programmes.first
    end

    test "builds a deterministic versioned SHA256 fingerprint" do
      first_fingerprint = fingerprint_for(@programme)
      second_fingerprint = fingerprint_for(@programme)

      assert_match(/\A[0-9a-f]{64}\z/, first_fingerprint)
      assert_equal first_fingerprint, second_fingerprint
      assert_equal 1, XmltvObservationFingerprint::VERSION
    end

    test "changes when significant observation data changes" do
      changed_programme = @programme.with(
        ends_at: @programme.ends_at + 1.minute,
        source_stop: "20260914010100 +0200"
      )

      assert_not_equal(
        fingerprint_for(@programme),
        fingerprint_for(changed_programme)
      )
    end

    test "ignores ordering differences in structured metadata" do
      first_programme = @programme.with(
        titles: [
          { value: "Titre", language: "fr" },
          { value: "Title", language: "en" }
        ]
      )
      second_programme = @programme.with(
        titles: [
          { language: "en", value: "Title" },
          { language: "fr", value: "Titre" }
        ]
      )

      assert_equal(
        fingerprint_for(first_programme),
        fingerprint_for(second_programme)
      )
    end

    private

    def fingerprint_for(programme)
      XmltvObservationFingerprint.new(
        guide_source: @source,
        programme: programme
      ).call
    end
  end
end
