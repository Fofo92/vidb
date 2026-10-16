# frozen_string_literal: true

require 'digest'
require 'json'

module VideoAssets
  class EncoderProjectAssociation
    def initialize(asset, project_path)
      @asset = asset
      @project = project_path
      @receipt = Pathname.new("#{asset.last_known_path}.video_encoder-export.json")
    end

    def call
      return 'legacy_same_name_and_chronology' unless @receipt.exist? || @receipt.symlink?
      raise ArgumentError, 'Export receipt must be a regular file without a symlink' unless regular_receipt?

      receipt = JSON.parse(@receipt.read)
      raise ArgumentError, 'Export receipt identifies a different project or copy' unless matches?(receipt)

      'export_receipt_project_digest'
    end

    private

    def regular_receipt?
      File.lstat(@receipt).file?
    end

    def matches?(receipt)
      stat = File.stat(@asset.last_known_path)
      receipt.is_a?(Hash) && receipt['format'] == 'video_encoder.completed_export' && receipt['version'] == 1 &&
        receipt['output_path'] == @asset.last_known_path &&
        receipt['project_sha256'] == Digest::SHA256.file(@project).hexdigest &&
        receipt['byte_size'] == stat.size && receipt['modified_at'] == stat.mtime.utc.iso8601(6)
    end
  end
end
