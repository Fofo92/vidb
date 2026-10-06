require "test_helper"

module Tv
  class XmltvRefreshTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
    end

    test "imports a downloaded guide and keeps it on a failed next download" do
      download = ->(path) { File.write(path, guide_xml) }
      imported = XmltvRefresh.new(guide_source: @source, downloader: download).call

      assert imported.status_succeeded?
      assert_equal 1, imported.programme_count
      assert_equal imported, @source.latest_successful_import

      failed = ->(_path) { raise "Téléchargement impossible" }
      assert_raises(RuntimeError) do
        XmltvRefresh.new(guide_source: @source, downloader: failed).call
      end
      assert_equal imported, @source.latest_successful_import
    end

    test "ignores an invalid programme outside the configured bouquet before parsing its times" do
      xml = guide_xml.sub("</tv>", <<~XML)
        <channel id="CanalPlus.fr"><display-name>Canal+</display-name></channel>
        <programme channel="CanalPlus.fr" start="invalid" stop="invalid">
          <title>Downton Abbey III</title>
        </programme>
        </tv>
      XML
      imported = refresh_xml(xml)

      assert_equal 1, imported.programme_count
      assert_equal ["TF1.fr"], imported.guide_import_channels.joins(:guide_channel).pluck("tv_guide_channels.external_id")
      assert_equal 1, imported.source_metadata.dig("download_filter", "excluded_programme_count")
    end

    test "reports and omits an invalid duration on an included channel" do
      invalid = <<~XML
        <programme channel="TF1.fr" start="20300101010000 +0100" stop="20300101010000 +0100">
          <title>Durée nulle</title>
        </programme>
        <programme channel="TF1.fr" start="20300101020000 +0100" stop="20300101010000 +0100">
          <title>Durée négative</title>
        </programme>
      XML
      imported = refresh_xml(guide_xml.sub("</tv>", "#{invalid}</tv>"))

      assert_equal 1, imported.programme_count
      rejected = imported.source_metadata.dig("download_filter", "rejected_programmes")
      assert_equal 2, rejected.size
      assert_equal "Durée nulle", rejected.first.fetch("title")
      assert_equal "non_positive_duration", rejected.first.fetch("reason")
    end

    test "refuses a guide with no valid programmes and keeps the previous import" do
      previous = refresh_xml(guide_xml)
      invalid = guide_xml.sub("20300101010000 +0100", "20300101000000 +0100")

      assert_raises(XmltvOverlapReview::InsufficientCoverage) { refresh_xml(invalid) }
      assert_equal previous, @source.latest_successful_import
    end

    test "keeps the previous import when an included programme has unreadable timestamps" do
      previous = refresh_xml(guide_xml)
      invalid = guide_xml.sub("20300101010000 +0100", "unreadable")

      assert_raises(ArgumentError) { refresh_xml(invalid) }
      assert_equal previous, @source.latest_successful_import
    end

    test "does not create another import for an identical filtered download" do
      previous = refresh_xml(guide_xml)

      assert_no_difference("GuideImport.count") do
        assert_equal previous, refresh_xml(guide_xml)
      end
    end

    test "compares only included channels against the previous unfiltered guide" do
      xml = guide_xml.sub("</tv>", <<~XML)
        <channel id="CanalPlus.fr"><display-name>Canal+</display-name></channel>
        <programme channel="CanalPlus.fr" start="20300101000000 +0100" stop="20300101010000 +0100">
          <title>Ancien programme Canal+</title>
        </programme>
        </tv>
      XML
      Tempfile.create(["unfiltered-guide", ".xml"]) do |file|
        File.write(file.path, xml)
        XmltvImporter.new(guide_source: @source, path: file.path).call
      end

      imported = refresh_xml(guide_xml)
      assert imported.status_succeeded?
      assert_equal 1, imported.programme_count
    end

    test "filters a compressed download" do
      download = lambda do |path|
        Zlib::GzipWriter.open(path) { |gzip| gzip.write(guide_xml) }
      end
      imported = XmltvRefresh.new(guide_source: @source, downloader: download).call

      assert_equal 1, imported.programme_count
    end

    test "keeps the previous import when XML is malformed" do
      previous = refresh_xml(guide_xml)

      assert_raises(Nokogiri::XML::SyntaxError) { refresh_xml("<tv><programme>") }
      assert_equal previous, @source.latest_successful_import
    end

    private

    def refresh_xml(xml)
      XmltvRefresh.new(guide_source: @source, downloader: ->(path) { File.write(path, xml) }).call
    end


    def guide_xml
      <<~XML
        <?xml version="1.0" encoding="UTF-8"?>
        <tv>
          <channel id="TF1.fr"><display-name>TF1</display-name></channel>
          <programme channel="TF1.fr" start="20300101000000 +0100" stop="20300101010000 +0100">
            <title lang="fr">Une émission</title>
          </programme>
        </tv>
      XML
    end
  end
end
