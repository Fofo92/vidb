# frozen_string_literal: true

require 'json'
require 'open3'
require 'time'

module VideoAssets
  # Validates a receipt against the current final file and its actual streams.
  class CompletedExport
    SUFFIX = '.video_encoder-export.json'

    def initialize(path)
      @path = path
    end

    def call
      receipt = JSON.parse(File.read("#{@path}#{SUFFIX}"))
      validate_receipt!(receipt)
      before = File.stat(@path)
      validate_file!(receipt, before)
      details = recorded_probe(receipt) || probe
      validate_probe!(receipt, details, before)
      { receipt: receipt, details: details, seconds: duration(details), signature: signature(before) }
    end

    private

    def recorded_probe(receipt)
      asset = VideoAsset.find_by(last_known_path: @path, status: 'present')
      return unless asset && asset.technical_details['video_encoder_export'] == receipt

      receipt.fetch('probe')
    end

    def validate_probe!(receipt, details, before)
      raise ArgumentError, 'Fichier modifié pendant le contrôle' unless signature(before) == signature(File.stat(@path))
      raise ArgumentError, 'Aucune piste vidéo finale' unless details.fetch('streams').any? do |stream|
        stream['codec_type'] == 'video'
      end
      raise ArgumentError, 'Pistes différentes du compte rendu' unless tracks(details) == tracks(receipt.fetch('probe'))

      seconds = duration(details)
      raise ArgumentError, 'Durée invalide' unless seconds.finite? && seconds.positive?
      return if (seconds - duration(receipt.fetch('probe'))).abs < 0.1

      raise ArgumentError,
            'Durée différente du compte rendu'
    end

    def duration(details)
      Float(details.fetch('format').fetch('duration'))
    end

    def validate_receipt!(receipt)
      raise ArgumentError, 'Compte rendu non reconnu' unless receipt['format'] == 'video_encoder.completed_export' &&
                                                             receipt['version'] == 1 && receipt['output_path'] == @path
      raise ArgumentError, 'Projet non identifié' unless receipt['project_sha256'].to_s.match?(/\A[0-9a-f]{64}\z/)
      raise ArgumentError, 'Rôles audio non reconnus' unless receipt['roles'].is_a?(Array) &&
                                                             (receipt['roles'] - %w[french original]).empty?
    end

    def validate_file!(receipt, stat)
      unchanged = stat.file? && stat.size == receipt['byte_size'] &&
                  stat.mtime.utc.iso8601(6) == receipt['modified_at']
      raise ArgumentError, 'Fichier différent du compte rendu' unless unchanged
    end

    def probe
      output, error, status = Open3.capture3('ffprobe', '-v', 'error', '-show_streams', '-show_format',
                                             '-of', 'json', @path)
      raise ArgumentError, "ffprobe : #{error}" unless status.success?

      JSON.parse(output)
    end

    def tracks(details)
      details.fetch('streams').map { |stream| stream.slice('index', 'codec_type', 'codec_name', 'tags', 'disposition') }
    end

    def signature(stat)
      [stat.size, stat.mtime, stat.ino]
    end
  end
end
