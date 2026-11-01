module EncoderProjects
  # Groups corroborating sources, never distinct TMDB identities or ambiguous matches.
  class FilmProposalGrouping
    def self.call(proposals)
      new(proposals).call
    end

    def initialize(proposals)
      @proposals = proposals.uniq { |item| source_key(item) }
    end

    def call
      replacements = {}.compare_by_identity
      wikipedia.each do |wiki|
        movie = paired_tmdb(wiki)
        next unless movie

        replacements[wiki] = combined(wiki, movie)
        replacements[movie] = nil
      end
      @proposals.filter_map { |item| replacements.key?(item) ? replacements[item] : item }
    end

    private

    def paired_tmdb(wiki)
      matches = tmdb.select { |movie| same_film?(wiki, movie) }
      return unless matches.one?

      movie = matches.first
      movie if wikipedia.one? { |other| same_film?(other, movie) }
    end

    def combined(wiki, movie)
      wiki.merge('additional_sources' => [movie.fetch('source')],
                 'poster_path' => movie['poster_path'], 'poster_source' => movie['source'])
    end

    def wikipedia
      @proposals.select { |item| item.dig('source', 'provider') == 'wikipedia' }
    end

    def tmdb
      @proposals.select { |item| item.dig('source', 'provider') == 'tmdb' }
    end

    def source_key(item)
      source = item.fetch('source', {})
      id = source['tmdb_movie_id'] || tmdb_url_id(source['url'])
      return ['tmdb', id.to_s] if source['provider'] == 'tmdb' && id.present?

      source['url'].present? ? [source['provider'], source['url']] : item.object_id
    end

    def tmdb_url_id(url)
      url.to_s[%r{\Ahttps://(?:www\.)?themoviedb\.org/movie/([1-9]\d*)(?:[-/?#]|\z)}, 1]
    end

    def same_film?(left, right)
      return false unless left['year'].present? && left['year'] == right['year']

      original = left['original_title'].to_s.parameterize
      return false if original.blank? || original != right['original_title'].to_s.parameterize

      title = left['french_title'].to_s.parameterize
      title.present? && title == right['french_title'].to_s.parameterize
    end
  end
end
