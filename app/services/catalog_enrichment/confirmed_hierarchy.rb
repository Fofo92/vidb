# frozen_string_literal: true

module CatalogEnrichment
  # Applies only a confirmed, initially empty series, or recognises an exact rerun.
  class ConfirmedHierarchy
    def initialize(record_id:, series_title:, episode_titles:)
      @record_id = record_id
      @series_title = series_title
      @titles = episode_titles
      raise ArgumentError, 'Nonempty episode titles required' unless valid_titles?
    end

    def call(apply: false)
      root = Record.find(@record_id)
      root.with_lock do
        validate_root!(root)
        status = hierarchy_status(root)
        create_hierarchy!(root) if apply && status == 'missing'
        { record_id: root.id, applied: apply && status == 'missing', previous_status: status,
          proposed_kind: 'series', season: 'Saison 01', episode_titles: @titles }
      end
    end

    private

    def valid_titles?
      @titles.is_a?(Array) && @titles.any? &&
        @titles.all? { |title| title.is_a?(String) && !title.strip.empty? }
    end

    def validate_root!(root)
      raise ArgumentError, 'Record title differs from confirmed title' unless root.french_title == @series_title
      raise ArgumentError, 'Record must be a series root' unless eligible_root?(root)
      raise ArgumentError, 'Root language version missing' unless root.language_version
    end

    def eligible_root?(root)
      root.root? && %w[undetermined series].include?(root.record_kind)
    end

    def hierarchy_status(root)
      children = root.children.lock.to_a
      return 'missing' if children.empty?

      unless root.record_kind == 'series' && children.one? && exact_season?(children.first)
        raise ArgumentError, 'Existing hierarchy differs; no records changed'
      end

      'already_present'
    end

    def exact_season?(season)
      return false unless season.record_kind == 'season' && season.rank == 1 && season.french_title == 'Saison 01'

      episodes = season.children.lock.order(:rank, :id).to_a
      episodes.length == @titles.length && episodes.each_with_index.all? do |episode, index|
        exact_episode?(episode, index)
      end
    end

    def exact_episode?(episode, index)
      episode.record_kind == 'episode' && episode.rank == index + 1 &&
        episode.french_title == @titles[index] && !episode.has_children?
    end

    def create_hierarchy!(root)
      root.update!(record_kind: 'series') if root.record_kind == 'undetermined'
      season = root.children.create!(attributes(root).merge(
                                       french_title: 'Saison 01', rank: 1, record_kind: 'season'
                                     ))
      @titles.each_with_index do |title, index|
        season.children.create!(attributes(root).merge(
                                  french_title: title, rank: index + 1, record_kind: 'episode'
                                ))
      end
    end

    def attributes(root)
      { language_version: root.language_version, is_seen: nil, is_recorded: nil,
        is_available: nil, is_checked: false }
    end
  end
end
