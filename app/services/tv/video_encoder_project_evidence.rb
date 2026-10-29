require 'json'

module Tv
  class VideoEncoderProjectEvidence
    MAX_BYTES = 2 * 1024 * 1024

    def call(asset)
      output = asset.last_known_path.to_s
      return :unknown unless output.start_with?('/')

      details = asset.technical_details
      receipt = details['video_encoder_export'] if details.is_a?(Hash)
      paths = project_paths(output, receipt)
      states = paths.map { |path| inspect_project(path, asset, receipt) }
      return :associated if states.include?(:associated)

      states.include?(:unknown) ? :unknown : :absent
    end

    private

    def project_paths(output, receipt)
      paths = ["#{output.sub(%r{\.[^/.]+\z}, '')}.json"]
      if receipt.is_a?(Hash) && receipt['output_path'] == output && receipt['project_path'].to_s.start_with?('/')
        paths.unshift(receipt['project_path'])
      end
      paths.uniq
    end

    def inspect_project(path, asset, receipt)
      document = read_project(path)
      return :absent unless project_document?(document)
      return :unknown unless compatible?(document, asset, receipt)

      :associated
    rescue Errno::ENOENT, Errno::ENOTDIR
      :absent
    rescue SystemCallError, IOError, JSON::ParserError, EncodingError, ArgumentError
      :unknown
    end

    def project_document?(document)
      document.is_a?(Hash) && document['format'] == 'video_encoder.trim_project' &&
        [1, 2].include?(document['version']) && document['timeline'].is_a?(Array) &&
        document['timeline'].any? { |item| item.is_a?(Hash) && item['type'] == 'segment' }
    end

    def read_project(path)
      raise ArgumentError, 'Projet non régulier' unless File.stat(path).file?

      File.open(path, 'rb') do |file|
        raise ArgumentError, 'Projet non régulier ou trop volumineux' unless file.stat.file?

        bytes = file.read(MAX_BYTES + 1)
        raise ArgumentError, 'Projet trop volumineux' if bytes.bytesize > MAX_BYTES

        JSON.parse(bytes)
      end
    end

    def compatible?(document, asset, receipt)
      binding = document['vidb']
      return false if binding.is_a?(Hash) && binding['record_id'] && binding['record_id'] != asset.record_id
      return true unless receipt.is_a?(Hash) && receipt['output_path'] == asset.last_known_path

      receipt['project_id'].blank? || document['project_id'] == receipt['project_id']
    end
  end
end
