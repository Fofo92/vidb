require 'nokogiri'
require 'uri'

module EncoderProjects
  class WikipediaSeasonEpisode
    def call(page, season, episode)
      entries(page, season)[episode]
    end

    def entries(page, season)
      doc = cleaned_document(page)
      heading = doc.css('h2, h3, h4').find do |node|
        node.text.squish.match?(/\ASaison\s+0*#{Integer(season)}(?:\s|\(|\z)/i)
      end
      return {} unless heading

      season_entries(page, heading, season_list(doc, heading))
    end

    private

    def cleaned_document(page)
      doc = Nokogiri::HTML.fragment(page.fetch('text').fetch('*'))
      doc.css('.mw-editsection, sup.reference, script, style').remove
      doc
    end

    def episode_title(item)
      return unless item
      return if item.at_css('ol, ul') || item.text.squish.match?(%r{\AÉpisode\s+\d+\s*/}i)

      item.text.squish.sub(/\A(?:Épisode|Enquête)\s+\d+\s*:\s*/i, '').split(/\s+:\s+/, 2).first
    end

    def season_list(doc, heading)
      nodes = doc.xpath('.//*').to_a
      following = nodes.drop(nodes.index(heading) + 1).take_while do |node|
        !node.name.match?(/\Ah[1-6]\z/) || node.name[1].to_i > heading.name[1].to_i
      end
      following.find { |node| node.name == 'ol' && node.ancestors.none? { |parent| parent.name == 'ol' } }
    end

    def season_entries(page, heading, list)
      return {} unless list

      number = Integer(list['start'] || 1)
      list.element_children.each_with_object({}) do |item, result|
        next unless item.name == 'li'

        number = Integer(item['value']) if item['value']
        title = episode_title(item)
        return {} if title.blank? || result.key?(number)

        result[number] = candidate(page, heading, title)
        number += 1
      end
    end

    def candidate(page, heading, title)
      years = heading.text.scan(/\b(?:19|20)\d{2}\b/).uniq
      url = "https://fr.wikipedia.org/wiki/#{URI::DEFAULT_PARSER.escape(page.fetch('title').tr(' ', '_'))}"
      { 'title' => title, 'year' => years.one? ? years.sole.to_i : nil, 'abstract' => '',
        'source' => { 'provider' => 'wikipedia', 'url' => url,
                      'season_heading' => heading.text.squish, 'page_title' => page.fetch('title'),
                      'numbering_basis' => 'season_ordered_list' } }
    end
  end
end
