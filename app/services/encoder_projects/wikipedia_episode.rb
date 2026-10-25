require 'nokogiri'
require 'uri'

module EncoderProjects
  class WikipediaEpisode
    def call(page, number)
      doc = Nokogiri::HTML.fragment(page.fetch('text').fetch('*'))
      doc.css('.mw-editsection, sup.reference').remove
      heading = doc.css('h2, h3, h4').find { |node| node.text.squish.match?(/\AÉpisode #{number}\s*:/i) }
      return unless heading

      section = section_after(heading)
      candidate(page, heading, section)
    end

    def candidate(page, heading, section)
      dates = labelled(section, 'Première diffusion')
      { 'title' => heading.text.squish.sub(/\AÉpisode \d+\s*:\s*/i, ''),
        'year' => dates.scan(/\b(?:19|20)\d{2}\b/).map(&:to_i).min,
        'abstract' => labelled(section, 'Résumé détaillé').truncate(1200),
        'source' => { 'provider' => 'wikipedia', 'url' => wiki_url(page.fetch('title')),
                      'diffusion_text' => dates.truncate(600) } }
    end

    def references(page)
      doc = Nokogiri::HTML.fragment(page.fetch('text').fetch('*'))
      { 'genres_text' => labelled(doc, 'Genre'), 'countries_text' => labelled(doc, "Pays d’origine").presence ||
        labelled(doc, "Pays d'origine") }
    end

    private

    def section_after(heading)
      node = heading.parent['class'].to_s.include?('mw-heading') ? heading.parent : heading
      fragment = Nokogiri::HTML.fragment('')
      while (node = node.next_element)
        break if node.name.match?(/\Ah[234]\z/) || node['class'].to_s.include?('mw-heading')

        fragment.add_child(node.dup)
      end
      fragment
    end

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
