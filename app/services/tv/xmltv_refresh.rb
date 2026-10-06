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
        channels = XmltvChannelSelection.new(@guide_source).call
        filtered = XmltvDownloadFilter.new(channel_ids: channels).call(file.path)
        import_filtered(file.path, channels, filtered)
      end
    end

    private

    def import_filtered(path, channels, filtered)
      document = XmltvReader.new(path).call
      review = XmltvOverlapReview.new(guide_source: @guide_source, document:, channel_ids: channels).call
      report(review)
      imported = XmltvImporter.new(guide_source: @guide_source, path:).call
      record_filter_results(imported, filtered)
      puts "Import réussi : #{imported.programme_count} programmes (n° #{imported.id})."
      imported
    end

    def record_filter_results(imported, filtered)
      details = {
        "excluded_programme_count" => filtered.excluded_programme_count,
        "rejected_programmes" => filtered.rejected_programmes
      }
      imported.update!(source_metadata: imported.source_metadata.merge("download_filter" => details))
      puts "Hors bouquet : #{filtered.excluded_programme_count} ; " \
           "durées invalides : #{filtered.rejected_programmes.size}."
    end

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
      puts "Sélections futures : #{review.renamed_intent_ids.size} variation(s) de présentation ou de métadonnées."
      report_intents("Numérotation discordante à examiner", review.numbering_intent_ids)
      report_intents(
        "Sélections sans correspondant fiable à la même plage (Kaffeine inchangé)",
        review.missing_intent_ids
      )
    end

    def report_intents(label, ids)
      puts "#{label} : #{ids.join(', ')}" if ids.any?
    end
  end
end
