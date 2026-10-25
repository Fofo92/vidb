module EncoderProjects
  class RecordPresentation
    def self.call(record)
      record.attributes.slice('french_title', 'original_title', 'year', 'record_kind', 'abstract').merge(
        'genres' => record.genders.map(&:name), 'countries' => record.countries.map(&:long_name)
      )
    end
  end
end
