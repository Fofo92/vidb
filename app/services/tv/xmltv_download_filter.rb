require "nokogiri"
require "time"
require "zlib"

module Tv
  class XmltvDownloadFilter
    attr_reader :rejected_programmes, :excluded_programme_count

    def initialize(channel_ids:)
      @channel_ids = channel_ids.to_set
      @rejected_programmes = []
      @excluded_programme_count = 0
    end

    def call(path)
      document = parse(path)
      document.xpath("/tv/channel").each { |node| node.remove unless included?(node["id"]) }
      document.xpath("/tv/programme").each { |node| filter_programme(node) }
      write(path, document)
      self
    end

    private

    def parse(path)
      contents = if File.binread(path, 2) == "\x1F\x8B".b
                   Zlib::GzipReader.open(path, &:read)
                 else
                   File.read(path)
                 end
      document = Nokogiri::XML(contents) { |configuration| configuration.strict.nonet }
      raise XmltvReader::InvalidDocument, "racine XMLTV tv absente" unless document.root&.name == "tv"

      document
    end

    def included?(channel_id)
      @channel_ids.include?(channel_id)
    end

    def filter_programme(node)
      unless included?(node["channel"])
        @excluded_programme_count += 1
        return node.remove
      end
      reject_programme(node) unless positive_duration?(node)
    end

    def positive_duration?(node)
      starts_at = Time.strptime(node["start"].to_s, "%Y%m%d%H%M%S %z")
      ends_at = Time.strptime(node["stop"].to_s, "%Y%m%d%H%M%S %z")
      starts_at < ends_at
    end

    def reject_programme(node)
      details = {
        "channel" => node["channel"], "title" => node.at_xpath("./title")&.text,
        "start" => node["start"], "stop" => node["stop"], "reason" => "non_positive_duration"
      }
      @rejected_programmes << details
      Rails.logger.warn("Programme XMLTV écarté : #{details.inspect}")
      node.remove
    end

    def write(path, document)
      Zlib::GzipWriter.open(path) do |gzip|
        gzip.mtime = 0
        gzip.write(document.to_xml)
      end
    end
  end
end
