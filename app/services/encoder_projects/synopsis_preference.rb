module EncoderProjects
  class SynopsisPreference
    PRIORITY = { 'tmdb' => 0, 'senscritique' => 1 }.freeze
    WIKIPEDIA_LIMIT = 900

    def self.rank(source)
      provider = source.is_a?(Hash) ? source['provider'] : nil
      { 'tmdb' => 0, 'senscritique' => 1, 'wikipedia' => 2 }.fetch(provider, 3)
    end

    def self.normalized_titles(names)
      names.compact_blank.map(&:parameterize).reject(&:blank?)
    end

    def self.call(proposals)
      proposals.map { |proposal| new(proposals).call(proposal) }
    end

    def initialize(proposals)
      @proposals = proposals
    end

    def call(proposal)
      return with_source(proposal, proposal) unless proposal.dig('source', 'provider') == 'wikipedia'

      matches = @proposals.select { |item| synopsis?(item) && same_work?(proposal, item) }
      selected = preferred(matches)
      return with_source(proposal, selected) if selected
      return with_source(proposal, proposal) if proposal['abstract'].to_s.length <= WIKIPEDIA_LIMIT

      proposal.merge('abstract' => '', 'abstract_notice' =>
        'Wikipédia fournit un récit détaillé. Aucun synopsis court concordant trouvé : résumé à compléter.')
    end

    private

    def synopsis?(proposal)
      PRIORITY.key?(proposal.dig('source', 'provider')) && proposal['abstract'].present?
    end

    def preferred(matches)
      return if matches.empty?

      rank = matches.map { |item| PRIORITY.fetch(item.dig('source', 'provider')) }.min
      best = matches.select { |item| PRIORITY.fetch(item.dig('source', 'provider')) == rank }
      best.first if best.map { |item| item['abstract'].squish }.uniq.one?
    end

    def same_work?(left, right)
      return false unless titles(left).intersect?(titles(right))
      return false if left['year'].present? && right['year'].present? && left['year'] != right['year']
      return same_episode?(left, right) if left.key?('series_id') || right.key?('series_id')

      left['year'].present? && left['year'] == right['year']
    end

    def same_episode?(left, right)
      %w[series_id season episode].all? { |field| left[field].present? && left[field] == right[field] }
    end

    def titles(proposal)
      self.class.normalized_titles(proposal.values_at('title', 'french_title', 'original_title'))
    end

    def with_source(proposal, synopsis)
      proposal.merge('abstract' => synopsis['abstract'].to_s,
                     'abstract_source' => synopsis.fetch('source', {}).deep_dup)
    end
  end
end
