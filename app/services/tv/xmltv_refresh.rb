require "tempfile"

module Tv
  class XmltvRefresh
    SOURCE_URL = "https://xmltvfr.fr/xmltv/xmltv_tnt.xml.gz".freeze

    def initialize(guide_source:, downloader: nil)
      @guide_source = guide_source
      @downloader = downloader || method(:download)
    end

    def call
      Tempfile.create(["vidb-xmltv-", ".xml.gz"], Rails.root.join("tmp")) do |file|
        @downloader.call(file.path)
        document = XmltvReader.new(file.path).call
        review = XmltvOverlapReview.new(guide_source: @guide_source, document:).call
        report(review)
        imported = XmltvImporter.new(guide_source: @guide_source, path: file.path).call
        puts "Import réussi : #{imported.programme_count} programmes (n° #{imported.id})."
        imported
      end
    end

    private

    def download(path)
      success = system(
        "curl", "--fail", "--location", "--silent", "--show-error",
        "--connect-timeout", "15", "--max-time", "180", "--retry", "2",
        "--output", path, SOURCE_URL
      )
      raise "Téléchargement XMLTV impossible" unless success
    end

    def report(review)
      return puts("Premier import : aucun guide antérieur à comparer.") unless review

      puts "Période commune : #{review.starts_at} – #{review.ends_at}"
      puts "Inchangés : #{review.unchanged} ; retirés ou modifiés : #{review.removed} ; nouveaux : #{review.added}"
      return if review.missing_intent_ids.empty?

      puts "Sélections vidb dont l’observation a changé ou disparu (programmation Kaffeine inchangée) : " \
           "#{review.missing_intent_ids.join(', ')}"
    end
  end
end
