module EncoderProjects
  class EpisodeTitles
    def self.display(french, original, countries: [])
      return original.to_s.strip if french.blank?

      title = french.to_s.strip
      other = original.to_s.strip
      french_work = countries.present? && countries.all? { |country| country.casecmp?('France') }
      duplicate = title.casecmp?(other) && french_work
      already_present = title.downcase.end_with?(" (#{other.downcase})")
      return title if other.blank? || duplicate || already_present

      "#{title} (#{other})"
    end

    def self.enrich(proposals)
      proposals.map do |proposal|
        next proposal if proposal['original_title'].present?

        matches = proposals.select { |item| item['original_title'].present? && concordant?(proposal, item) }
        names = matches.map { |item| item['original_title'].squish.downcase }.uniq
        next proposal unless names.one?

        selected = matches.first
        proposal.merge('original_title' => selected['original_title'],
                       'original_title_source' => selected['original_title_source'] || selected['source'])
      end
    end

    def self.concordant?(left, right)
      placement = %w[series_id season episode].all? { |field| left[field].present? && left[field] == right[field] }
      same_year = left['year'].blank? || right['year'].blank? || left['year'] == right['year']
      title = left['title'].to_s.parameterize
      placement && same_year && title.present? && title == right['title'].to_s.parameterize
    end
  end
end
