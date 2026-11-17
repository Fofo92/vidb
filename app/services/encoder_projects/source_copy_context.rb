# frozen_string_literal: true

module EncoderProjects
  class SourceCopyContext
    def self.call(data, record)
      return {} unless data['source_copy_id']

      asset = record.video_assets.find(data.fetch('source_copy_id'))
      raise ArgumentError, 'La copie à convertir doit être une copie MKV présente.' unless valid?(asset)

      { 'source_copy' => { 'id' => asset.id, 'path' => asset.last_known_path } }
    end

    def self.valid?(asset)
      path = asset.last_known_path
      asset.status_present? && path.is_a?(String) && path.start_with?('/videos/') &&
        path.end_with?('.mkv') && !path.match?(/[[:cntrl:]]/) && !path.split('/').include?('..')
    end
  end
end
