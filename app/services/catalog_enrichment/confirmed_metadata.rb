# frozen_string_literal: true

module CatalogEnrichment
  class ConfirmedMetadata
    def initialize(records:, episodes:, countries:, genres:, year:)
      @records = records
      @episodes = episodes
      @country_ids = countries.map { |name| unique_entry!(Country.where(long_name: name), name).id }.sort
      @genre_ids = [unique_entry!(Gender.where('LOWER(name) IN (?)', genres.map(&:downcase)), genres.join(' / ')).id]
      @year = year
    end

    def plan
      @records.each { |record| validate_metadata!(record) }
      @records.map do |record|
        { record_id: record.id, country_ids: @country_ids, gender_ids: @genre_ids,
          episode_year: @episodes.include?(record) ? @year : nil }
      end
    end

    def apply!
      plan
      @records.each do |record|
        record.country_ids = @country_ids unless record.country_ids.sort == @country_ids
        record.gender_ids = @genre_ids unless record.gender_ids.sort == @genre_ids
        record.year = @year if @episodes.include?(record)
        record.save! if record.changed?
      end
    end

    private

    def unique_entry!(scope, name)
      entries = scope.to_a
      raise ArgumentError, "Missing or ambiguous dictionary entry: #{name}" unless entries.one?

      entries.first
    end

    def validate_metadata!(record)
      raise ArgumentError, "Country conflict on record #{record.id}" unless (record.country_ids - @country_ids).empty?
      raise ArgumentError, "Genre conflict on record #{record.id}" unless (record.gender_ids - @genre_ids).empty?
      return unless @episodes.include?(record) && record.year && record.year != @year

      raise ArgumentError, "Production year conflict on episode #{record.id}"
    end
  end
end
