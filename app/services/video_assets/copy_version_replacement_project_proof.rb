# frozen_string_literal: true

require 'digest'
require 'json'
require 'time'

module VideoAssets
  # Accepts a missing original project only with its archived video and export receipt.
  class CopyVersionReplacementProjectProof
    SUFFIX = '.video_encoder-export.json'

    def initialize(change, path, record_id)
      @change = change
      @path = path
      @record_id = record_id
      @project = change.fetch('archived_project_path')
    end

    def valid?(manifest)
      return recovered_project?(manifest) unless @change['source_project_missing_before_replacement'] == true
      return false if File.exist?(@project) || File.symlink?(@project) || manifest.key?(old_project)
      return false unless archived_video?(manifest)

      receipt = archived_receipt(manifest)
      receipt.is_a?(Hash) && receipt_project?(receipt) && receipt_video?(receipt)
    end

    private

    def old_project
      @path.sub(/\.mkv\z/, '.json')
    end

    def recovered_project?(manifest)
      manifest[old_project] == @project && regular?(@project) &&
        Digest::SHA256.file(@project).hexdigest == @change['source_project_sha256']
    end

    def archived_video?(manifest)
      archived = @change.fetch('archived_source_path')
      @change['source_missing_before_replacement'] == false && manifest[@path] == archived && regular?(archived)
    end

    def archived_receipt(manifest)
      path = @change.fetch('archived_source_path') + SUFFIX
      return unless manifest[@path + SUFFIX] == path && regular?(path) && File.size(path) <= 2.megabytes

      JSON.parse(File.read(path))
    end

    def regular?(path)
      File.file?(path) && !File.symlink?(path)
    end

    def receipt_project?(receipt)
      receipt['format'] == 'video_encoder.completed_export' && receipt['version'] == 1 &&
        receipt['project_path'] == old_project && receipt['output_path'] == @path &&
        receipt['project_sha256'] == @change['source_project_sha256'] &&
        receipt['project_sha256'].is_a?(String) && receipt['project_sha256'].match?(/\A[0-9a-f]{64}\z/)
    end

    def receipt_video?(receipt)
      identity = @change['source_identity']
      return false unless identity.is_a?(Hash) && identity['mtime_ns'].is_a?(Integer)

      modified = (Time.iso8601(receipt.fetch('modified_at')).to_r * 1_000_000).to_i
      receipt.dig('vidb', 'record_id') == @record_id && receipt['byte_size'] == identity['size'] &&
        modified == identity['mtime_ns'] / 1000
    end
  end
end
