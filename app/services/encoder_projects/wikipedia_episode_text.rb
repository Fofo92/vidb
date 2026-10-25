module EncoderProjects
  # Reads an episode by document order, independently of the HTML nesting of its fields.
  class WikipediaEpisodeText
    LABELS = ['Titre original', 'Numéro de production', 'Première diffusion', 'Audiences',
              'Résumé détaillé', 'Résumé', 'Invités', 'Commentaires', 'Réalisation', 'Scénario', 'Durée'].freeze

    def initialize(doc, heading)
      nodes = doc.xpath('.//text()').to_a
      last_heading = nodes.index(heading.xpath('.//text()').last)
      following = nodes.drop(last_heading + 1).take_while { |node| !terminal_heading?(node, heading) }
      @text = following.map { |node| node.text.squish }.reject(&:empty?).join("\n")
    end

    def value(label)
      match = pattern([label]).match(@text)
      return '' unless match

      following = @text[match.end(0)..]
      boundary = pattern(LABELS).match(following)
      (boundary ? following[0...boundary.begin(0)] : following).squish
    end

    private

    def terminal_heading?(node, heading)
      next_heading = node.ancestors.find { |parent| parent.name.match?(/\Ah[1-6]\z/) }
      return false unless next_heading && next_heading.name[1].to_i <= heading.name[1].to_i
      return false if LABELS.any? { |label| next_heading.text.squish.delete_suffix(':').strip.casecmp?(label) }

      true
    end

    def pattern(labels)
      names = labels.map { |label| Regexp.escape(label).gsub('\\ ', '\\s+') }.join('|')
      Regexp.new("(?:\\A|\\n)[\\t ]*(?:#{names})[\\t ]*(?::[\\t ]*|\\n|\\z)", Regexp::IGNORECASE)
    end
  end
end
