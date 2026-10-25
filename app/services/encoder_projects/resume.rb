require 'digest'
require 'json'

module EncoderProjects
  # Retry offline project requests from the exact document captured by a completed export.
  class Resume
    def self.call(receipt)
      return unless ProjectRequest::UUID.match?(receipt['project_id'].to_s) && File.file?(Settings::PATH)

      document = project_document(receipt)
      return unless document

      config = Settings.read
      data = { 'project_id' => document.fetch('project_id'), 'project_path' => receipt.fetch('project_path'),
               'output_path' => receipt.fetch('output_path'), 'source_paths' => source_paths(document) }
      result = Identification.new(user: User.find(config.fetch('user_id')), url: config.fetch('url')).call(data)
      Record.find(result.fetch(:binding).fetch('record_id')) if result[:status] == 'identified'
    end

    def self.project_document(receipt)
      path = receipt['project_path'].to_s
      return unless valid_project_file?(path)

      text = File.read(path)
      return unless Digest::SHA256.hexdigest(text) == receipt['project_sha256']

      data = JSON.parse(text)
      data if data.is_a?(Hash) && data['project_id'] == receipt['project_id']
    rescue Errno::ENOENT, Errno::EACCES, JSON::ParserError
      nil
    end

    def self.valid_project_file?(path)
      path.start_with?('/videos/') && File.lstat(path).file? && File.size(path) <= 2_097_152 &&
        File.realpath(path).start_with?('/videos/')
    end

    def self.source_paths(document)
      return document.fetch('sources').map { |source| source.fetch('path') } if document['version'] == 2

      document.fetch('timeline').filter_map { |item| item['source'] }.uniq
    end
  end
end
