module EncoderProjects
  class ProjectRequest
    UUID = /\A[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}\z/
    attr_reader :data

    def initialize(data)
      @data = data.slice('project_id', 'project_path', 'output_path', 'source_paths')
      validate!
    end

    def project_id
      data.fetch('project_id')
    end

    private

    def validate!
      raise ArgumentError, 'Identifiant de projet invalide' unless UUID.match?(data['project_id'].to_s)
      raise ArgumentError, 'Destination hors de la vidéothèque' unless valid_output?(data['output_path'])
      unless data['project_path'] == data['output_path'].sub(/\.mkv\z/, '.json')
        raise ArgumentError, 'Le projet et sa destination doivent partager le même nom'
      end

      sources = data['source_paths']
      return if sources.is_a?(Array) && sources.size.between?(0, 16) && sources.all? { |path| absolute_path?(path) }

      raise ArgumentError, 'Sources de projet invalides'
    end

    def valid_output?(path)
      absolute_path?(path) && path.start_with?('/videos/') && path.end_with?('.mkv')
    end

    def absolute_path?(path)
      path.is_a?(String) && path.length <= 4096 && path.start_with?('/') &&
        !path.match?(/[[:cntrl:]]/) && !path.split('/').include?('..')
    end
  end
end
