require "digest"

module Tv
  # This service coordinates the complete import workflow; keeping the steps
  # together makes the transaction boundaries and failure handling explicit.
  class XmltvImporter
    def initialize(guide_source:, path:)
      @guide_source = guide_source
      @path = path
      @document_sha256 = Digest::SHA256.file(@path).hexdigest
      @document_byte_size = File.size(@path)
    end

    def call
      guide_import = successful_import
      return synchronize_existing_channels(guide_import) if guide_import

      import_document(XmltvReader.new(@path).call)
    rescue StandardError => e
      XmltvImportFailureRecorder.new(
        @guide_source, @document_sha256, @document_byte_size, e
      ).call
      raise
    end

    private

    def synchronize_existing_channels(guide_import)
      ChannelCatalogSynchronizer.new(@guide_source).call
      guide_import
    end

    def successful_import
      @guide_source.guide_imports.status_succeeded.find_by(
        document_sha256: @document_sha256
      )
    end

    def import_document(document)
      GuideImport.transaction do
        guide_import = create_import(document)
        guide_channels = persist_guide_channels(document)
        persist_import_data(guide_import, document, guide_channels)
      end
    end

    def persist_guide_channels(document)
      XmltvImportChannelPersister.new(
        guide_source: @guide_source,
        channels: document.channels
      ).call
    end

    def persist_import_data(guide_import, document, guide_channels)
      persist_channel_coverages(guide_import, document, guide_channels)
      persist_observations(guide_import, document, guide_channels)
      complete_import(guide_import)
    end

    def create_import(document)
      @guide_source.guide_imports.create!(
        document_sha256: @document_sha256,
        document_byte_size: @document_byte_size,
        **document_results(document),
        source_metadata: source_metadata(document)
      )
    end

    def persist_channel_coverages(guide_import, document, guide_channels)
      coverages = XmltvCoverage.new(document.programmes).call

      document.channels.each do |external_id, channel|
        create_channel_coverage(
          guide_import, guide_channels.fetch(external_id),
          channel, coverages[external_id]
        )
      end
    end

    def create_channel_coverage(guide_import, guide_channel, channel, coverage)
      guide_import.guide_import_channels.create!(
        guide_channel: guide_channel,
        display_names: stringify_entries(channel.display_names),
        **coverage_attributes(coverage)
      )
    end

    def coverage_attributes(coverage)
      return {} unless coverage

      gaps = coverage.gaps.map { |gap| gap_attributes(gap) }

      {
        programme_count: coverage.programme_count,
        first_starts_at: coverage.starts_at,
        last_ends_at: coverage.ends_at,
        gap_count: gaps.size,
        total_gap_duration_seconds: total_gap_duration(gaps),
        gaps: gaps
      }
    end

    def total_gap_duration(gaps)
      gaps.sum { |gap| gap.fetch("duration_seconds") }
    end

    def gap_attributes(gap)
      {
        "starts_at" => gap.starts_at.iso8601,
        "ends_at" => gap.ends_at.iso8601,
        "duration_seconds" => gap.duration_seconds
      }
    end

    def stringify_entries(entries)
      entries.map(&:stringify_keys)
    end

    def complete_import(guide_import)
      guide_import.update!(status: "succeeded", finished_at: Time.current)
      guide_import
    end

    def document_results(document)
      {
        channel_count: document.channels.size,
        source_programme_count: document.programmes.size + document.duplicate_programme_count,
        programme_count: document.programmes.size,
        duplicate_programme_count: document.duplicate_programme_count
      }
    end

    def source_metadata(document)
      {
        source_info_name: document.source_info_name,
        source_info_url: document.source_info_url,
        generator_info_name: document.generator_info_name,
        generator_info_url: document.generator_info_url
      }
    end

    def persist_observations(guide_import, document, guide_channels)
      XmltvImportObservationPersister.new(
        guide_source: @guide_source,
        guide_import: guide_import,
        guide_channels: guide_channels,
        programmes: document.programmes
      ).call
    end
  end
end
