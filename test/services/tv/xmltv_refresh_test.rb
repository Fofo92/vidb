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

    private

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
