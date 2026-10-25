module EncoderProjects
  class CatalogueEpisodeMetadata
    def initialize(source_url:)
      @source_url = source_url
    end

    def call(record, row)
      attributes = year_attributes(record, row)
      attributes[:original_title] = row['title_original'] if record.original_title.blank?
      record.update!(attributes) if attributes.any?
      return unless row['overview_fr'].present? && !record.abstract_protected?
      return if record.abstract.present?

      record.save_external_abstract!(row['overview_fr'], source: source(row))
    end

    def source(row)
      path = "/season/#{row.fetch('season_number')}/episode/#{row.fetch('episode_number')}"
      { 'provider' => 'tmdb', 'url' => "#{@source_url}#{path}",
        'episode_id' => row.fetch('tmdb_episode_id'), 'first_air_date' => row['first_air_date'] }
    end

    private

    def year_attributes(record, row)
      date = row['first_air_date'].to_s
      return {} unless record.year.nil? && date.match?(/\A\d{4}-\d{2}-\d{2}\z/) && date <= Date.current.iso8601

      { year: date[0, 4].to_i, year_basis: 'first_release', year_evidence: source(row) }
    end
  end
end
