require "test_helper"
require "tempfile"
require "zlib"

module Tv
  class XmltvReaderTest < ActiveSupport::TestCase
    setup do
      @document = XmltvReader.new(
        file_fixture("tv/guide.xml")
      ).call
      @channel = @document.channels.fetch("France2.fr")
      @programme = @document.programmes.first
    end

    test "reads source metadata" do
      assert_equal "XML TV Fr", @document.source_info_name
      assert_equal(
        "https://github.com/racacax/XML-TV-Fr",
        @document.source_info_url
      )
      assert_equal "XML TV Fr", @document.generator_info_name
      assert_equal(
        "https://github.com/racacax/XML-TV-Fr",
        @document.generator_info_url
      )
    end

    test "reads channel metadata" do
      assert_equal(
        [{ value: "France 2", language: "fr" }],
        @channel.display_names
      )
    end

    test "reads programme identity and timing" do
      assert_equal 1, @document.programmes.size
      assert_equal "France2.fr", @programme.channel_id
      assert_equal(
        Time.new(2026, 9, 13, 14, 5, 0, "+02:00"),
        @programme.starts_at
      )
      assert_equal(
        Time.new(2026, 9, 13, 14, 55, 0, "+02:00"),
        @programme.ends_at
      )
    end

    test "reads programme metadata" do
      assert_equal(
        [{ value: "Un si grand soleil", language: "fr" }],
        @programme.titles
      )
      assert_equal(
        [{ value: "Épisode du dimanche", language: "fr" }],
        @programme.subtitles
      )
      assert_equal(
        [{ value: "Résumé de l’épisode.", language: "fr" }],
        @programme.descriptions
      )
      assert_equal(
        [{ value: "Série dramatique", language: "fr" }],
        @programme.categories
      )
      assert_equal(
        [{ value: "7.42.", system: "xmltv_ns" }],
        @programme.episode_numbers
      )
    end

    test "reads a gzip document detected from its content" do
      Tempfile.create(["guide", ".xml"]) do |file|
        path = file.path
        file.close

        Zlib::GzipWriter.open(path) do |gzip|
          gzip.write File.binread(file_fixture("tv/guide.xml"))
        end

        document = XmltvReader.new(path).call

        assert_equal "XML TV Fr", document.source_info_name
        assert_equal 1, document.programmes.size
      end
    end

    test "preserves missing optional metadata" do
      document = XmltvReader.new(
        file_fixture("tv/minimal_guide.xml")
      ).call
      channel = document.channels.fetch("France3.fr")
      programme = document.programmes.first

      assert_nil document.source_info_name
      assert_equal(
        [{ value: "France 3", language: nil }],
        channel.display_names
      )
      assert_empty programme.subtitles
      assert_empty programme.descriptions
      assert_empty programme.categories
      assert_empty programme.episode_numbers
    end

    test "reports an invalid XMLTV document" do
      Tempfile.create(["invalid-guide", ".xml"]) do |file|
        file.write("<tv><programme>")
        file.close

        error = assert_raises(XmltvReader::InvalidDocument) do
          XmltvReader.new(file.path).call
        end

        assert_match(/document XMLTV invalide/, error.message)
      end
    end
  end
end
