# frozen_string_literal: true

module VideoAssets
  # Classifies evidence, without claiming that a correction is safe to apply.
  class BlockageCategory
    REASONS = {
      'container_unmatched' => 'series_identification',
      'container_ambiguous' => 'ambiguous_identification',
      'season_unmatched' => 'missing_season',
      'season_ambiguous' => 'ambiguous_hierarchy',
      'episode_unmatched' => 'missing_episode',
      'season_number_conflict' => 'numbering_conflict',
      'inventory_number_conflict' => 'numbering_conflict'
    }.freeze
    STATUSES = {
      'unmatched' => 'work_identification',
      'episode_title_variant' => 'title_variant',
      'episode_title_conflict' => 'title_conflict',
      'ambiguous_episode' => 'ambiguous_identification',
      'ambiguous_exact' => 'ambiguous_identification',
      'ambiguous_convention' => 'ambiguous_identification'
    }.freeze
    FOLLOWUP = {
      'confirmed' => 'confirmed',
      'awaiting_stability' => 'awaiting_stability',
      'confirmed_copy_changed' => 'copy_changed',
      'candidate' => 'candidate'
    }.freeze

    def self.call(entry)
      exclusion = excluded_category(entry)
      return exclusion if exclusion

      state = FOLLOWUP[entry[:followup_status]]
      return state if state
      return ineligible(entry) if entry[:reason] == 'container_ineligible'

      REASONS[entry[:reason]] || STATUSES[entry[:status]] || 'other_review'
    end

    def self.excluded_category(entry)
      return 'excluded_trash' if components(entry).any? { |part| part.start_with?('.Trash') }
      return 'excluded_workspace' if components(entry).any? { |part| workspace?(part) }

      nil
    end

    def self.components(entry)
      entry.fetch(:path).split('/')
    end

    def self.workspace?(part)
      part.start_with?('video_encoder_') && part.end_with?('_workspace')
    end

    def self.ineligible(entry)
      candidates = entry.fetch(:container_candidates, [])
      return 'ambiguous_identification' unless candidates.one?

      candidate = candidates.first
      return 'parent_placement' if candidate[:non_root]
      return 'missing_hierarchy' if candidate[:has_children] == false

      'container_kind_review'
    end
    private_class_method :components, :workspace?, :ineligible, :excluded_category
  end
end
