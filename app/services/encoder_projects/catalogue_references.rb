module EncoderProjects
  class CatalogueReferences
    def self.genres(candidate)
      text = candidate.fetch('genres_text').downcase
      names = Gender.all.select { |item| text.include?(item.name.downcase) }
      names = Gender.where(name: ['Drame', 'Comédie']).to_a if text.include?('comédie dramatique')
      names.first(2).map(&:id) if names.size <= 2
    end

    def self.countries(candidate)
      codes = candidate.fetch('country_codes', []).map(&:upcase)
      text = candidate.fetch('countries_text', '').downcase
      Country.all.select do |item|
        codes.include?(item.short_name.upcase) || text.include?(item.long_name.downcase)
      end.map(&:id)
    end
  end
end
