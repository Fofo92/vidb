require 'nokogiri'
require 'uri'

module EncoderProjects
  class WikipediaFilm
    def call(page)
      @document = Nokogiri::HTML.fragment(page.fetch('text').fetch('*'))
      @rows = rows
      return unless film?

      attributes(page)
    end

    private

    def rows
      @document.css('.infobox tr, .infobox_v2 tr, .infobox_v3 tr').filter_map do |row|
        label = row.at_css('th')&.text&.squish
        cell = row.at_css('td')
        [label, cell.text.squish] if label && cell
      end.to_h
    end

    def field(pattern)
      @rows.find { |label, _value| label.match?(pattern) }&.last.to_s
    end

    def film?
      field(/Réalisation/i).present? && field(/Genre/i).present? && field(/Sortie/i).match?(/\b(?:19|20)\d{2}\b/) &&
        @document.css('p').any? { |paragraph| paragraph.text.match?(/\bfilm\b/i) }
    end

    def attributes(page)
      { 'french_title' => page.fetch('title').sub(/ \(film.*\)\z/i, ''),
        'original_title' => field(/Titre original/i), 'year' => field(/Sortie/i)[/\b(?:19|20)\d{2}\b/].to_i,
        'genres_text' => field(/Genre/i), 'countries_text' => field(/Pays.*production|Pays d.origine/i),
        'abstract' => synopsis, 'source' => source(page), 'record_kind' => 'standalone_video' }
    end

    def source(page)
      url = "https://fr.wikipedia.org/wiki/#{URI.encode_www_form_component(page.fetch('title')).tr('+', '_')}"
      { 'provider' => 'wikipedia', 'url' => url, 'page_id' => page.fetch('pageid'),
        'observed_at' => Time.current.iso8601, 'year_reference' => 'Année de sortie de l’infobox Wikipédia' }
    end

    def synopsis
      marker = @document.at_css('#Synopsis, #Résumé, #Resume')
      unless marker
        return @document.css('p').find do |paragraph|
          paragraph.text.squish.present?
        end&.text&.squish.to_s
      end

      node = marker.ancestors.find { |ancestor| ancestor.name.match?(/\Ah[1-6]\z/) } || marker
      node = node.parent if node.parent['class'].to_s.include?('mw-heading')
      paragraphs_after(node).join("\n\n")
    end

    def paragraphs_after(node)
      output = []
      node = node.next_element
      while node && !node.name.match?(/\Ah[1-6]\z/) && !node['class'].to_s.include?('mw-heading')
        output << node.text.squish if node.name == 'p' && node.text.squish.present?
        node = node.next_element
      end
      output
    end
  end
end
