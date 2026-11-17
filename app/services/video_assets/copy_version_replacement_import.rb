# frozen_string_literal: true

require 'digest'
require 'json'

module VideoAssets
  # Releases the old path only from a verified, recoverable replacement receipt.
  class CopyVersionReplacementImport
    def initialize(record, observation, export)
      @record = record
      @path = observation.fetch(:path)
      @receipt = export.fetch(:receipt)
      @change = @receipt['copy_version_replacement']
    end

    def call
      return unless @change

      asset = VideoAsset.find_by(last_known_path: @path)
      return unless asset
      return if asset.record_id == @record.id && asset.technical_details['video_encoder_export'] == @receipt

      validate_archive!
      validate_asset!(asset)
      archive_asset(asset)
    end

    private

    def validate_archive!
      raise ArgumentError, 'Archive de remplacement invalide.' unless @change.is_a?(Hash) && valid_paths?

      project = @change.fetch('archived_project_path')
      manifest = read_manifest
      old_project = @path.sub(/\.mkv\z/, '.json')
      valid = manifest[old_project] == project && regular?(project) &&
              Digest::SHA256.file(project).hexdigest == @change['source_project_sha256']
      raise ArgumentError, 'Ancien projet non récupérable ou différent du reçu.' unless valid
    end

    def valid_paths?
      values = @change.values_at('source_path', 'archived_source_path', 'archive_directory', 'archived_project_path')
      return false unless valid_strings?(values)

      source, archived, directory, project = values
      source == @path && directory.start_with?("#{File.dirname(@path)}/.video_encoder_trash/") &&
        Pathname(directory).cleanpath.to_s == directory && File.realpath(directory) == directory &&
        [archived, project].all? { |path| File.dirname(path) == directory } &&
        @receipt.dig('version_change', 'source_path') == archived
    end

    def valid_strings?(values)
      values.all? { |path| path.is_a?(String) && !path.include?("\0") }
    end

    def read_manifest
      path = File.join(@change.fetch('archive_directory'), 'manifest.json')
      raise ArgumentError, 'Manifeste de récupération absent ou invalide.' unless readable_manifest?(path)

      JSON.parse(File.read(path))
    end

    def readable_manifest?(path)
      regular?(path) && File.size(path) <= 2.megabytes
    end

    def regular?(path)
      File.file?(path) && !File.symlink?(path)
    end

    def validate_asset!(asset)
      identity = @change.fetch('source_identity')
      raise ArgumentError, 'La référence ancienne ne correspond pas à la copie remplacée.' unless
        asset.record_id == @record.id && identity.is_a?(Hash) && asset.byte_size == identity['size']

      archived = @change.fetch('archived_source_path')
      return if @change['source_missing_before_replacement'] == true && !File.exist?(archived)

      valid = regular?(archived) && signature(archived) == identity
      raise ArgumentError, 'Ancienne vidéo différente de la source archivée.' unless valid
    end

    def signature(path)
      stat = File.stat(path)
      { 'size' => stat.size, 'mtime_ns' => (stat.mtime.to_r * 1_000_000_000).to_i,
        'inode' => stat.ino, 'device' => stat.dev }
    end

    def archive_asset(asset)
      event = { 'directory' => @change.fetch('archive_directory'), 'original_path' => @path,
                'origin' => 'video_encoder_version_replacement', 'removed_at' => @change['replaced_at'] }
      details = asset.technical_details.merge('copy_removal' => event)
      asset.update!(status: 'deleted', last_known_path: @change.fetch('archived_source_path'),
                    technical_details: details)
    end
  end
end
