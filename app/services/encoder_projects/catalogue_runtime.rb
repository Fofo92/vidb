module EncoderProjects
  class CatalogueRuntime
    def self.import(record, candidate)
      return if record.length_in_mn.present?

      minutes = candidate['reference_runtime_minutes']
      return unless minutes.is_a?(Integer) && minutes.between?(record.minimum_catalogue_length, 240)

      record.update!(length_in_mn: minutes)
    end

    def self.enrich(proposals)
      proposals.map do |proposal|
        next proposal if proposal['reference_runtime_minutes'].present?

        matches = proposals.select { |other| same_film?(proposal, other) }
        durations = matches.filter_map { |other| other['reference_runtime_minutes'] }.uniq
        durations.one? ? proposal.merge('reference_runtime_minutes' => durations.sole) : proposal
      end
    end

    def self.same_film?(left, right)
      return false unless left['year'].present? && left['year'] == right['year']

      fields = ['french_title', 'original_title']
      a = SynopsisPreference.normalized_titles(left.values_at(*fields))
      b = SynopsisPreference.normalized_titles(right.values_at(*fields))
      a.intersect?(b)
    end
    private_class_method :same_film?

    def self.from_text(value)
      text = value.to_s.squish
      match = text.match(/\A(?:(\d+)\s*h(?:eures?)?\s*)?(?:(\d+)\s*(?:min(?:utes?)?)?)?\z/i)
      return unless match&.captures&.any?(&:present?)

      positive_minutes((match[1].to_i * 60) + match[2].to_i)
    end

    def self.from_iso(value)
      match = value.to_s.match(/\APT(?:(\d+)H)?(?:(\d+)M)?(?:(\d+)S)?\z/i)
      return unless match&.captures&.any?(&:present?)

      positive_minutes(((match[1].to_i * 3600) + (match[2].to_i * 60) + match[3].to_i) / 60.0)
    end

    def self.positive_minutes(value)
      minutes = value.round
      minutes if minutes.positive?
    end
    private_class_method :positive_minutes
  end
end
