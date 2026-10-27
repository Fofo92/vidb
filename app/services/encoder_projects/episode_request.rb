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

      apply_target(project['episode_target']) if project.key?('episode_target')
    end

    def apply_target(target)
      valid = target.is_a?(Hash) && target['season'].is_a?(Integer) && target['episode'].is_a?(Integer) &&
              target['season'].between?(0, 99) && target['episode'].between?(1, 999)
      raise ArgumentError, 'Saison ou numéro d’épisode invalide' unless valid

      @title = '' if @season != target['season'] || @episode != target['episode']
      @season = target['season']
      @episode = target['episode']
    end
    private :apply_target

    def self.match?(project)
      new(project)
      true
    rescue ArgumentError
      false
    end
  end
end
