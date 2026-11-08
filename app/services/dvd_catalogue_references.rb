class DvdCatalogueReferences
  def initialize(tmdb: nil, references: EncoderProjects::CatalogueReferences)
    @tmdb = tmdb
    @references = references
  end

  def call(params)
    fields = params.permit(dvd_references: [:tmdb_series_id, :genres_text, :countries_text, { country_codes: [] }])
    candidate = fields.to_h.fetch("dvd_references", {}).stringify_keys
    candidate = series_references(candidate.fetch("tmdb_series_id")) if candidate["tmdb_series_id"].present?
    { gender_ids: genre_ids(candidate), country_ids: @references.countries(candidate) }
  end

  private

  def series_references(id)
    raise ArgumentError, "Identifiant de série invalide" unless id.to_s.match?(/\A[1-9]\d*\z/)

    row = tmdb.get("tv/#{id}")
    raise ArgumentError, "Identité de série différente" unless row.fetch("id").to_s == id.to_s

    codes = row.fetch("production_countries", []).pluck("iso_3166_1").compact
    { "genres_text" => row.fetch("genres", []).pluck("name").join(", "),
      "country_codes" => codes.presence || row.fetch("origin_country", []) }
  end

  def genre_ids(candidate)
    text = candidate.fetch("genres_text", "")
    resolved = @references.genres(candidate.merge("genres_text" => text))
    resolved ||= text.split(",").flat_map { |name| @references.genres("genres_text" => name) || [] }
    resolved.uniq.first(2)
  end

  def tmdb
    @tmdb ||= EncoderProjects::TmdbSeriesClient.new(cache_dir: Rails.root.join("tmp/catalogue-episodes"))
  end
end
