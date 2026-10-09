# frozen_string_literal: true

module CatalogEnrichment
  # Uses the original first-air date preserved in the existing TMDB link.
  class LinkedEpisodeYears
    def initialize(root_record_id:, apply: false)
      @root = Record.find(root_record_id)
      raise ArgumentError, 'Expected a series root' unless @root.record_kind_series? && @root.ancestry.blank?

      @apply = apply
    end

    def call
      Record.transaction do
        records = @root.descendants.order(:id).lock.to_a
        links = CatalogueEpisodeLink.where(record_id: records.map(&:id), provider: 'tmdb').order(:id).lock.to_a
        plans = links.filter_map { |link| proposal(link, records) }
        plans.each { |plan| apply_plan(plan, records) } if @apply
        { applied: @apply, root_record_id: @root.id, total: plans.length, episodes: plans }
      end
    end

    private

    def proposal(link, records)
      raw_date = link.evidence['first_air_date']
      return if raw_date.blank?

      date = checked_date(raw_date)
      record = records.find { |item| item.id == link.record_id }
      raise ArgumentError, "Not an episode: #{record.id}" unless record.record_kind_episode?

      { record_id: record.id, previous_year: record.year, previous_basis: record.year_basis,
        year: date.year, evidence: evidence(link, raw_date) }
    end

    def checked_date(value)
      date = Date.iso8601(value)
      raise ArgumentError, 'Invalid first-air date' unless date.iso8601 == value

      date
    end

    def evidence(link, date)
      { 'provider' => 'tmdb', 'catalogue_episode_link_id' => link.id,
        'external_episode_id' => link.external_episode_id, 'first_air_date' => date,
        'source_snapshot_retrieved_at' => link.evidence['source_snapshot_retrieved_at'],
        'convention' => 'original_first_air_date' }
    end

    def apply_plan(plan, records)
      record = records.find { |item| item.id == plan.fetch(:record_id) }
      record.update!(year: plan.fetch(:year), year_basis: 'first_release', year_evidence: plan.fetch(:evidence))
    end
  end
end
