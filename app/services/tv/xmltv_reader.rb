require "nokogiri"
require "time"
require "zlib"

module Tv
  class XmltvReader
    TIME_FORMAT = "%Y%m%d%H%M%S %z".freeze

    class InvalidDocument < StandardError
    end

    GZIP_MAGIC = "\x1F\x8B".b.freeze
    def initialize(path)
      @path = path
    end

    def call
      root = parse.root
      programmes, duplicate_programme_count = read_programmes(root)

      build_document(
        root,
        programmes,
        duplicate_programme_count
      )
    end

    private

    def parse
      Nokogiri::XML(document_contents) do |configuration|
        configuration.strict.nonet
      end
    rescue Nokogiri::XML::SyntaxError, Zlib::GzipFile::Error => e
      raise InvalidDocument,
            "document XMLTV invalide : #{e.message}"
    end

    def document_contents
      return File.binread(@path) unless gzip?

      Zlib::GzipReader.open(@path, &:read)
    end

    def gzip?
      File.binread(@path, GZIP_MAGIC.bytesize) == GZIP_MAGIC
    end

    def build_document(root, programmes, duplicate_programme_count)
      XmltvDocument.new(
        source_info_name: root["source-info-name"],
        source_info_url: root["source-info-url"],
        generator_info_name: root["generator-info-name"],
        generator_info_url: root["generator-info-url"],
        channels: read_channels(root),
        programmes: programmes,
        duplicate_programme_count: duplicate_programme_count
      )
    end

    def read_channels(root)
      root.xpath("./channel").to_h do |node|
        channel = XmltvChannel.new(
          external_id: node["id"],
          display_names: localized_values(node, "./display-name")
        )

        [channel.external_id, channel]
      end
    end

    def read_programmes(root)
      nodes = root.xpath("./programme")
      unique_nodes = nodes.uniq(&:to_xml)

      [
        unique_nodes.map { |node| build_programme(node) },
        nodes.size - unique_nodes.size
      ]
    end

    def build_programme(node)
      XmltvProgramme.new(
        channel_id: node["channel"],
        **programme_timing(node),
        titles: localized_values(node, "./title"),
        subtitles: localized_values(node, "./sub-title"),
        descriptions: localized_values(node, "./desc"),
        categories: localized_values(node, "./category"),
        episode_numbers: episode_numbers(node)
      )
    end

    def programme_timing(node)
      starts_at = parse_time(node["start"])
      ends_at = parse_time(node["stop"])

      validate_interval!(starts_at, ends_at)

      {
        starts_at: starts_at,
        ends_at: ends_at
      }
    end

    def validate_interval!(starts_at, ends_at)
      return if ends_at > starts_at

      raise InvalidDocument,
            "la fin doit être postérieure au début"
    end

    def localized_values(node, xpath)
      node.xpath(xpath).map do |value_node|
        {
          value: value_node.text.strip,
          language: value_node["lang"]
        }
      end
    end

    def episode_numbers(node)
      node.xpath("./episode-num").map do |value_node|
        {
          value: value_node.text.strip,
          system: value_node["system"]
        }
      end
    end

    def parse_time(value)
      Time.strptime(value, TIME_FORMAT)
    end
  end
end
