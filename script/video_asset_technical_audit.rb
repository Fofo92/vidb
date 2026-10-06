# frozen_string_literal: true

require "json"
require "open3"

module VideoAssetTechnicalAudit
  module_function

  def call(root_id)
    root = Record.find(root_id)
    ids = [root.id, *root.descendants.pluck(:id)]
    assets = VideoAsset.where(record_id: ids).includes(record: [:language_version, :media]).order(:id)
    {
      format: "vidb.video_asset_technical_audit", version: 1,
      generated_at: Time.current.iso8601, rails_environment: Rails.env,
      root_record_id: root.id, root_title: root.complete_title,
      language_versions: LanguageVersion.order(:id).map { |entry| entry.attributes.slice("id", "short_name", "long_name") },
      media: Medium.order(:id).map { |entry| entry.attributes.slice("id", "short_name", "long_name") },
      assets: assets.map { |asset| asset_report(asset) }
    }
  end

  def asset_report(asset)
    record = asset.record
    {
      video_asset_id: asset.id, record_id: record.id, title: record.complete_title,
      stored_status: asset.status, stored_path: asset.last_known_path,
      stored_byte_size: asset.byte_size, stored_observed_at: asset.observed_at,
      catalogue_language_version: record.language_version&.attributes&.slice("id", "short_name", "long_name"),
      catalogue_media: record.media.map { |entry| entry.attributes.slice("id", "short_name", "long_name") },
      current_file: observe(asset.last_known_path)
    }
  end

  def observe(path)
    raise ArgumentError, "Stored path is empty" if path.blank?

    before = File.stat(path)
    raise ArgumentError, "Not a regular file" unless before.file?

    real_path = File.realpath(path)
    probe = run_json("ffprobe", "-v", "error", "-show_format", "-show_streams", "-of", "json", real_path)
    storage = mounted_storage(real_path)
    after = File.stat(path)
    raise ArgumentError, "File changed during observation" unless identity(before) == identity(after)

    {
      observation_status: "observed", real_path:, byte_size: after.size,
      modified_at: after.mtime.iso8601, storage:,
      format: probe.fetch("format", {}).slice("format_name", "duration", "size"),
      streams: probe.fetch("streams", []).map { |stream| stream_report(stream) },
      sidecar_subtitles: subtitle_paths(real_path)
    }
  rescue StandardError => e
    { observation_status: "not_observed", error_class: e.class.name, error: e.message }
  end

  def identity(stat)
    [stat.dev, stat.ino, stat.size, stat.mtime, stat.ctime]
  end

  def run_json(*command)
    output, error, status = Open3.capture3(*command)
    raise "#{command.first} failed: #{error.strip}" unless status.success?

    JSON.parse(output)
  end

  def mounted_storage(path)
    run_json("findmnt", "--json", "--target", path, "--output", "SOURCE,TARGET,FSTYPE,UUID,LABEL")
      .fetch("filesystems", [])
  rescue StandardError => e
    { observation_status: "unavailable", error: e.message }
  end

  def stream_report(stream)
    language = stream.fetch("tags", {})["language"]
    stream.slice("index", "codec_type", "codec_name", "profile", "channels", "channel_layout",
                 "sample_rate", "width", "height", "disposition").merge(
      "tags" => stream.fetch("tags", {}).slice("language", "title", "handler_name"),
      "language_evidence" => language.blank? || %w[und qaa].include?(language.downcase) ? "unidentified" : "declared_tag"
    )
  end

  def subtitle_paths(path)
    directory = File.dirname(path)
    stem = File.basename(path, File.extname(path))
    Dir.children(directory).filter_map do |name|
      next unless name.start_with?("#{stem}.") && %w[.srt .ass .ssa .vtt .sub .idx].include?(File.extname(name).downcase)

      candidate = File.join(directory, name)
      candidate if File.file?(candidate)
    end.sort
  rescue SystemCallError
    []
  end
end

root_id = Integer(ARGV.fetch(0, "3060"), 10)
output_path = ARGV[1] ? Pathname.new(ARGV[1]) : Rails.root.join("tmp", "video-asset-technical-audit-#{root_id}.json")
report = VideoAssetTechnicalAudit.call(root_id)
output_path.dirname.mkpath
output_path.write(JSON.pretty_generate(report) << "\n")
puts JSON.pretty_generate(
  root_record_id: root_id,
  assets: report.fetch(:assets).map do |entry|
    observed = entry.fetch(:current_file)
    { video_asset_id: entry.fetch(:video_asset_id), title: entry.fetch(:title),
      status: observed.fetch(:observation_status), error: observed[:error] }
  end
)
puts output_path
