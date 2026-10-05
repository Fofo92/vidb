#!/usr/bin/env ruby
# frozen_string_literal: true

require "find"
require "json"
require "optparse"
require "time"

module VideoLibraryInventory
  FORMAT = "vidb.video_library_inventory"
  VERSION = 1
  RELEVANT_EXTENSIONS = %w[.json .m2t .mkv .ts].freeze

  SERIES_DIRECTORY = /\A(?<title>.+?) \((?<seasons>[IVXLCDM]+) - (?<validated>\d+)_(?<total>\d+)\)\z/i
  SEASON_DIRECTORY = /\A(?:Saison|Season) (?<number>\d+)(?: \((?<validated>\d+)_(?<total>\d+)\))?\z/i
  EPISODE_NAME = /\bS(?<season>\d+)\s*E(?<episode>\d+)\b/i

  module EntrySerialization
    def build_entry(root, path, stat)
      if stat.directory?
        directory_entry(root, path, stat)
      elsif stat.symlink?
        symlink_entry(root, path, stat)
      elsif stat.file? && relevant_file?(path)
        file_entry(root, path, stat)
      end
    end

    def base_entry(root, path, stat, type)
      {
        root: root.to_s,
        path: path.to_s,
        relative_path: relative_path(root, path),
        type: type,
        size: stat.size,
        modified_at: stat.mtime.iso8601
      }
    end

    def directory_entry(root, path, stat)
      entry = base_entry(root, path, stat, "directory")
      entry[:classification] = classify_directory(path.basename.to_s)
      entry
    end

    def file_entry(root, path, stat)
      base_entry(root, path, stat, "file").merge(
        extension: path.extname.downcase,
        stem: path.basename(path.extname).to_s,
        episode: parse_episode(path.basename.to_s)
      )
    end

    def symlink_entry(root, path, stat)
      base_entry(root, path, stat, "symlink").merge(
        target: path.readlink.to_s
      )
    rescue Errno::ENOENT, Errno::EINVAL
      base_entry(root, path, stat, "symlink").merge(target: nil)
    end

    def classify_directory(name)
      if (match = SERIES_DIRECTORY.match(name))
        series_classification(match)
      elsif (match = SEASON_DIRECTORY.match(name))
        season_classification(match)
      else
        { kind: "unclassified" }
      end
    end

    def series_classification(match)
      {
        kind: "series_with_progress",
        title: match[:title],
        declared_seasons: match[:seasons],
        declared_validated: match[:validated].to_i,
        declared_total: match[:total].to_i,
        zero_padded: padded?(match[:validated]) && padded?(match[:total])
      }
    end

    def season_classification(match)
      {
        kind: "season",
        number: match[:number].to_i,
        number_zero_padded: padded?(match[:number]),
        declared_validated: integer_or_nil(match[:validated]),
        declared_total: integer_or_nil(match[:total]),
        progress_zero_padded: progress_padding(match)
      }
    end

    def parse_episode(name)
      match = EPISODE_NAME.match(name)
      return unless match

      {
        season: match[:season].to_i,
        episode: match[:episode].to_i,
        season_zero_padded: padded?(match[:season]),
        episode_zero_padded: padded?(match[:episode])
      }
    end

    def relevant_file?(path)
      include_all_files || RELEVANT_EXTENSIONS.include?(path.extname.downcase)
    end

    def relative_path(root, path)
      path.relative_path_from(root).to_s
    end

    def padded?(value)
      value && value.length >= 2
    end

    def integer_or_nil(value)
      value&.to_i
    end

    def progress_padding(match)
      return nil unless match[:validated] && match[:total]

      padded?(match[:validated]) && padded?(match[:total])
    end
  end

  module InventoryAnalysis
    def build_pairs(entries)
      grouped = relevant_pairs(entries).group_by do |entry|
        [File.dirname(entry[:path]), entry[:stem]]
      end
      pairs = grouped.map { |identity, files| build_pair(identity, files) }
      pairs.sort_by { |pair| [pair[:directory], pair[:stem]] }
    end

    def relevant_pairs(entries)
      entries.select do |entry|
        entry[:type] == "file" && %w[.json .mkv].include?(entry[:extension])
      end
    end

    def build_pair(identity, files)
      directory, stem = identity
      extensions = files.map { |file| file[:extension] }.uniq.sort
      {
        directory: directory, stem: stem, extensions: extensions,
        status: pair_status(extensions),
        paths: files.map { |file| file[:path] }.sort
      }
    end

    def build_warnings(entries)
      entries.filter_map do |entry|
        code = warning_code(entry)
        { code: code, path: entry[:path] } if code
      end
    end

    def warning_code(entry)
      classification = entry[:classification]
      series_warning(classification) || season_warning(classification) ||
        episode_warning(entry[:episode])
    end

    def series_warning(classification)
      return unless classification&.fetch(:kind) == "series_with_progress"
      return if classification[:zero_padded]

      "series_progress_not_zero_padded"
    end

    def season_warning(classification)
      return unless classification&.fetch(:kind) == "season"
      return "season_number_not_zero_padded" unless classification[:number_zero_padded]
      return "season_progress_not_zero_padded" if classification[:progress_zero_padded] == false
    end

    def episode_warning(episode)
      return unless episode
      return if episode[:season_zero_padded] && episode[:episode_zero_padded]

      "episode_number_not_zero_padded"
    end

    def pair_status(extensions)
      return "json_and_mkv" if extensions == %w[.json .mkv]
      return "json_only" if extensions == [".json"]

      "mkv_only"
    end
  end

  class Scanner
    include EntrySerialization
    include InventoryAnalysis

    def initialize(roots:, include_all_files: false)
      @roots = roots.map { |root| Pathname.new(root).expand_path }
      @include_all_files = include_all_files
    end

    def call
      entries = roots.flat_map { |root| scan_root(root) }
      {
        format: FORMAT, version: VERSION, generated_at: Time.now.iso8601,
        roots: roots.map(&:to_s), entries: entries,
        pairs: build_pairs(entries), warnings: build_warnings(entries)
      }
    end

    private

    attr_reader :roots, :include_all_files

    def scan_root(root)
      return [missing_root(root)] unless root.exist?

      entries = []
      Find.find(root.to_s) { |path| scan_path(root, path, entries) }
      entries
    end

    def scan_path(root, path_string, entries)
      path = Pathname.new(path_string)
      entry = build_entry(root, path, path.lstat)
      entries << entry if entry
    rescue Errno::EACCES => e
      entries << inaccessible_entry(root, path, e)
      Find.prune if path&.directory?
    rescue Errno::ENOENT
      nil
    end

    def missing_root(root)
      { root: root.to_s, path: root.to_s, type: "missing_root" }
    end

    def inaccessible_entry(root, path, error)
      {
        root: root.to_s,
        path: path&.to_s,
        type: "inaccessible",
        error: error.message
      }
    end
  end

  class CLI
    def initialize(argv, output: $stdout)
      @argv = argv
      @output = output
      @options = { include_all_files: false, pretty: true }
    end

    def run
      parser.parse!(argv)
      abort(parser.to_s) if argv.empty?

      result = Scanner.new(
        roots: argv,
        include_all_files: options[:include_all_files]
      ).call
      output.puts(options[:pretty] ? JSON.pretty_generate(result) : JSON.generate(result))
    end

    private

    attr_reader :argv, :output, :options

    def parser
      @parser ||= OptionParser.new do |command|
        command.banner = "Usage: ruby script/video_library_inventory.rb [options] ROOT [ROOT...]"
        command.on("--all-files", "Include every regular file") { options[:include_all_files] = true }
        command.on("--compact", "Write compact JSON") { options[:pretty] = false }
      end
    end
  end
end

VideoLibraryInventory::CLI.new(ARGV).run if $PROGRAM_NAME == __FILE__
