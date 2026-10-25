module EncoderProjects
  class WikipediaSeasonTitle
    def self.call(series, number)
      connector = series.match?(/\A[aeiouyàâäéèêëîïôöùûüœ]/i) ? "d'" : 'de '
      "Saison #{number} #{connector}#{series}"
    end
  end
end
