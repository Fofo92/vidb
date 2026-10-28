require 'nokogiri'
require 'json'

module EncoderProjects
  class SenscritiqueFilm
    def call(html, url:)
      document = Nokogiri::HTML(html)
      movie = structured_movie(document)
      return structured_attributes(movie, url) if movie && movie['name'].to_s.strip.present?

      meta_attributes(document, url)
    end

    private

    def structured_movie(document)
      document.css('script[type="application/ld+json"]').each do |script|
        movie = json_nodes(JSON.parse(script.text)).find { |node| Array(node['@type']).include?('Movie') }
        return movie if movie
      rescue JSON::ParserError
        next
      end
      nil
    end

    def json_nodes(value)
      case value
      when Array then value.flat_map { |item| json_nodes(item) }
      when Hash then [value] + json_nodes(value.fetch('@graph', []))
      else []
      end
    end

    def structured_attributes(movie, url)
      base(url).merge('french_title' => clean(movie['name']), 'original_title' => clean(movie['alternateName']),
                      'year' => movie['datePublished'].to_s[/\A(?:19|20)\d{2}/]&.to_i,
                      'genres_text' => names(movie['genre']), 'countries_text' => names(movie['countryOfOrigin']),
                      'abstract' => clean(movie['description']),
                      'reference_runtime_minutes' => CatalogueRuntime.from_iso(movie['duration']))
    end

    def meta_attributes(document, url)
      title = document.at_css('meta[property="og:title"]')&.[]('content').to_s
      match = title.match(/\A(.+?)\s+-\s+(?:Téléfilm|Film)(?:\s+\((\d{4})\))?\s*-\s*SensCritique\z/i)
      return unless match

      base(url).merge('french_title' => clean(match[1]), 'year' => match[2]&.to_i,
                      'abstract' => '', 'abstract_notice' =>
                        'SensCritique : métadonnées structurées absentes ; complète les champs manquants.')
    end

    def names(value)
      Array.wrap(value).filter_map { |item| item.is_a?(Hash) ? item['name'] : item }.join(', ')
    end

    def clean(value)
      return '' unless value.is_a?(String)

      Nokogiri::HTML.fragment(value).text.squish
    end

    def base(url)
      { 'record_kind' => 'standalone_video', 'original_title' => '', 'genres_text' => '', 'countries_text' => '',
        'source' => { 'provider' => 'senscritique', 'url' => url, 'observed_at' => Time.current.iso8601,
                      'year_reference' => 'Année de publication indiquée par SensCritique' } }
    end
  end
end
