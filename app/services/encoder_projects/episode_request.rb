module EncoderProjects
  class EpisodeRequest
    PATTERN = /S(\d{1,2})\s*E(\d{1,3})\s*[-–—]?\s*(.*)/i
    attr_reader :season, :episode, :title, :series

    def initialize(project)
      paths = Array(project['source_paths']) + [project['output_path']]
      match_path = paths.find { |path| PATTERN.match?(File.basename(path.to_s)) }
      match = PATTERN.match(File.basename(match_path.to_s, File.extname(match_path.to_s)))
      raise ArgumentError, 'Numéro de saison et épisode absent' unless match

      @season = match[1].to_i
      @episode = match[2].to_i
      @title = match[3].sub(/_vf\z/i, '').strip
      @series = File.basename(match_path).split(/\s*[-–—]\s*S\d/i).first
      raise ArgumentError, 'Numéro d’épisode invalide' unless @episode.positive?
    end

    def self.match?(project)
      new(project)
      true
    rescue ArgumentError
      false
    end
  end
end
