class DvdSeriesImport
  def initialize(client: nil)
    @client = client || EncoderProjects::TmdbSeriesClient.new(cache_dir: Rails.root.join("tmp/catalogue-episodes"))
  end

  def call(ean:, series_id:)
    raise ArgumentError, "EAN invalide" unless DvdEdition.valid_ean?(ean)
    raise ArgumentError, "Identifiant de série invalide" unless series_id.to_s.match?(/\A[1-9]\d*\z/)

    @snapshot = CatalogEnrichment::TmdbSeriesSnapshot.new(client: @client, series_id: series_id,
                                                          include_specials: true).call.deep_stringify_keys
    Record.transaction { import(ean) }
  end

  private

  def import(ean)
    root = EncoderProjects::SeriesCreation.new(candidate).call
    edition = DvdEdition.create_or_find_by!(ean: ean) { |item| item.record = root }
    edition.lock!
    raise ArgumentError, "Cet EAN est associé à une autre fiche." unless edition.record_id == root.id

    complete_metadata(root)
    EncoderProjects::SeriesCatalogueCompletion.new(root: root, snapshot: @snapshot).call
    complete_seasons(root)
    edition
  end

  def candidate
    row = @snapshot.fetch("series")
    { "tmdb_id" => row.fetch("id"), "french_title" => row.fetch("name"),
      "original_title" => row["original_name"], "year" => row["first_air_date"].to_s[/\A\d{4}/]&.to_i,
      "source" => { "provider" => "tmdb", "url" => @snapshot.fetch("source_url") } }
  end

  def complete_metadata(root)
    fields = ActionController::Parameters.new(dvd_references: { tmdb_series_id: @snapshot.fetch("tmdb_series_id") })
    references = DvdCatalogueReferences.new(tmdb: @client).call(fields)
    root.gender_ids = references.fetch(:gender_ids) if root.gender_ids.empty?
    root.country_ids = references.fetch(:country_ids) if root.country_ids.empty?
    root.save! if root.changed?
    complete_abstract(root, @snapshot.fetch("series")["overview"], @snapshot.fetch("source_url"))
  end

  def complete_seasons(root)
    @snapshot.fetch("series").fetch("seasons").each do |season|
      number = season.fetch("season_number")
      row = @client.get("tv/#{@snapshot.fetch('tmdb_series_id')}/season/#{number}")
      record = root.children.find_by!(record_kind: "season", rank: number)
      complete_abstract(record, row["overview"], "#{@snapshot.fetch('source_url')}/season/#{number}")
    end
  end

  def complete_abstract(record, text, url)
    return if text.blank? || record.abstract.present? || record.abstract_protected?

    record.save_external_abstract!(text, source: { "provider" => "tmdb", "url" => url })
  end
end
