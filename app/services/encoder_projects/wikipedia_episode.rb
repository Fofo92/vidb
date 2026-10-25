require 'nokogiri'
require 'uri'

module EncoderProjects
  class WikipediaEpisode
    def call(page, number)
      doc = Nokogiri::HTML.fragment(page.fetch('text').fetch('*'))
      doc.css('.mw-editsection, sup.reference, script, style').remove
      heading = doc.css('h2, h3, h4').find { |node| node.text.squish.match?(/\AÉpisode #{number}\s*:/i) }
      return unless heading

      section = WikipediaEpisodeText.new(doc, heading)
      candidate(page, heading, section)
    end

    def candidate(page, heading, section)
      dates = section.value('Première diffusion')
      { 'title' => heading.text.squish.sub(/\AÉpisode \d+\s*:\s*/i, ''),
        'year' => dates.scan(/\b(?:19|20)\d{2}\b/).map(&:to_i).min,
        'abstract' => section.value('Résumé détaillé').presence || section.value('Résumé'),
        'source' => { 'provider' => 'wikipedia', 'url' => wiki_url(page.fetch('title')),
                      'diffusion_text' => dates.truncate(600) } }
    end

    def references(page)
      doc = Nokogiri::HTML.fragment(page.fetch('text').fetch('*'))
      { 'genres_text' => labelled(doc, 'Genre'), 'countries_text' => labelled(doc, "Pays d’origine").presence ||
        labelled(doc, "Pays d'origine") }
    end

    private

    def labelled(doc, label)
      node = doc.css('th, dt, div, span, b, strong').find { |item| item.text.squish == label }
      return '' unless node

      value = node.next_element || node.parent.next_element
      value ? value.text.squish : ''
    end

    def wiki_url(title)
      "https://fr.wikipedia.org/wiki/#{URI::DEFAULT_PARSER.escape(title.tr(' ', '_'))}"
    end
  end
end
