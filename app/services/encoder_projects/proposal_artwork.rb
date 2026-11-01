module EncoderProjects
  # The API supplies only a file name; arbitrary remote URLs are never embedded.
  class ProposalArtwork
    def self.url(proposal)
      path = proposal['poster_path']
      unless path.is_a?(String) && path.bytesize <= 200 && path.match?(%r{\A/[A-Za-z0-9_-]+\.(?:jpg|jpeg|png|webp)\z}i)
        return
      end

      "https://image.tmdb.org/t/p/w185#{path}"
    end
  end
end
