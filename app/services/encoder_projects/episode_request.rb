module EncoderProjects
  class EpisodeRequest
    PATTERN = /S(?:aison)?\s*(\d{1,2})\s*(?:[,;:–—-]\s*)?[EÉé](?:pisode)?\s*(\d{1,3})\s*[-–—:]?\s*(.*)/i
    attr_reader :season, :episode, :title, :series

    def initialize(project)
      match_path, match = source_match(project)
      if !match && project.key?('episode_target')
        explicit_request(project, Array(project['source_paths']))
        return
      end

      raise ArgumentError, 'Numéro de saison et épisode absent' unless match

      numbered_request(match_path, match)

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

    def source_match(project)
      query = project['episode_search'].to_s
      return [nil, PATTERN.match(query)] if PATTERN.match?(query)

      paths = Array(project['source_paths']) + [project['output_path']]
      path = paths.find { |value| PATTERN.match?(File.basename(value.to_s)) }
      [path, PATTERN.match(File.basename(path.to_s, File.extname(path.to_s)))]
    end
    private :source_match

    def numbered_request(_path, match)
      @season = match[1].to_i
      @episode = match[2].to_i
      @title = match[3].sub(/_vf\z/i, '').strip
      @series = match.pre_match.sub(/\s*[-–—]\s*\z/, '').strip
      raise ArgumentError, 'Numéro d’épisode invalide' unless @episode.positive?
    end
    private :numbered_request

    def explicit_request(project, paths)
      @series = File.basename(paths.first.to_s, File.extname(paths.first.to_s))
      @title = ''
      apply_target(project['episode_target'])
    end
    private :explicit_request

    def self.match?(project)
      new(project)
      true
    rescue ArgumentError
      false
    end

    def self.with_query(project, query)
      return project unless PATTERN.match?(query.to_s)

      selected = project.except('episode_target').merge('episode_search' => query.to_s.strip)
      new(selected)
      selected
    rescue ArgumentError
      project
    end
  end
end
