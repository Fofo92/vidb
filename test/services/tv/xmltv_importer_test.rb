require "test_helper"
require "digest"

module Tv
  class XmltvImporterTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      @path = file_fixture("tv/minimal_guide.xml")
      @guide_import = XmltvImporter.new(
        guide_source: @source,
        path: @path
      ).call
    end

    test "persists a minimal document as a successful import" do
      assert @guide_import.persisted?
      assert @guide_import.status_succeeded?
      assert @guide_import.finished_at
      assert_equal Digest::SHA256.file(@path).hexdigest, @guide_import.document_sha256
      assert_equal File.size(@path), @guide_import.document_byte_size
      assert_equal 1, @guide_import.channel_count
      assert_equal 1, @guide_import.source_programme_count
      assert_equal 1, @guide_import.programme_count
      assert_equal 0, @guide_import.duplicate_programme_count
      assert_equal 1, @guide_import.guide_import_channels.count
      assert_equal 1, @guide_import.broadcast_observations.count
    end
    test "persists the external channel and its coverage" do
      guide_channel = @source.guide_channels.find_by!(
        external_id: "France3.fr"
      )
      assert_equal 3, guide_channel.channel.logical_number
      assert_equal "France 3", guide_channel.channel.display_name

      coverage = @guide_import.guide_import_channels.find_by!(
        guide_channel: guide_channel
      )

      assert_equal(
        [{ "value" => "France 3", "language" => nil }],
        guide_channel.display_names
      )
      assert_equal guide_channel.display_names, coverage.display_names
      assert_equal 1, coverage.programme_count
      assert_equal Time.new(2026, 9, 14, 0, 5, 0, "+02:00"),
                   coverage.first_starts_at
      assert_equal Time.new(2026, 9, 14, 1, 0, 0, "+02:00"),
                   coverage.last_ends_at
      assert_empty coverage.gaps
    end

    test "persists the observation and its source metadata" do
      observation = @guide_import.broadcast_observations.first!

      assert_equal "France3.fr",
                   observation.guide_channel.external_id
      assert_equal "20260914000500 +0200",
                   observation.source_start
      assert_equal "20260914010000 +0200",
                   observation.source_stop
      assert_equal(
        [
          {
            "value" => "Programme sans métadonnées facultatives",
            "language" => "fr"
          }
        ],
        observation.titles
      )
      assert_empty observation.subtitles
      assert_equal 1, observation.fingerprint_version
      assert_match(/\A[0-9a-f]{64}\z/, observation.fingerprint)
    end

    test "persists the declared document metadata" do
      expected_metadata = {
        "source_info_name" => nil,
        "source_info_url" => nil,
        "generator_info_name" => nil,
        "generator_info_url" => nil
      }

      assert_equal expected_metadata,
                   @guide_import.source_metadata
    end

    test "reuses a successful import of the same document" do
      repeated_import = XmltvImporter.new(
        guide_source: @source,
        path: @path
      ).call

      assert_equal @guide_import, repeated_import
      assert_equal 1, @source.guide_imports.count
      assert_equal 1, @source.guide_channels.count
      assert_equal 1, GuideImportChannel.count
      assert_equal 1, BroadcastObservation.count
      assert_equal 1, GuideImportObservation.count
    end
  end
end
