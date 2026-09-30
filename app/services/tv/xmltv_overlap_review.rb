module Tv
  # Reviews only the time shared by the current and incoming XMLTV snapshots.
  class XmltvOverlapReview
    class InsufficientCoverage < StandardError; end

    Result = Data.define(
      :starts_at, :ends_at, :unchanged, :removed, :added,
      :renamed_intent_ids, :numbering_intent_ids, :missing_intent_ids
    )
    MINIMUM_CHANNEL_RATIO = 0.7
    HORIZON_TOLERANCE = 6.hours

    def initialize(guide_source:, document:)
      @guide_source = guide_source
      @document = document
    end

    def call
      incoming = @document.programmes
      validate_incoming!(incoming)

      previous = @guide_source.latest_successful_import
      return unless previous

      existing = previous.broadcast_observations.includes(:guide_channel).to_a
      starts_at, ends_at = common_period(existing, incoming)
      old_entries = existing.select { |entry| overlaps?(entry, starts_at, ends_at) }
      new_entries = incoming.select { |entry| overlaps?(entry, starts_at, ends_at) }
      verify_channels!(old_entries, new_entries)
      compare(old_entries, new_entries, starts_at, ends_at)
    end

    private

    def validate_incoming!(incoming)
      raise InsufficientCoverage, "nouveau guide vide" if incoming.empty?
      raise InsufficientCoverage, "aucun programme futur" unless incoming.any? { |entry| entry.ends_at > Time.current }
    end

    def common_period(existing, incoming)
      raise InsufficientCoverage, "guide courant vide" if existing.empty?

      starts_at = [existing.map(&:starts_at).min, incoming.map(&:starts_at).min].max
      ends_at = [existing.map(&:ends_at).max, incoming.map(&:ends_at).max].min
      raise InsufficientCoverage, "aucune période commune avec le guide courant" unless starts_at < ends_at

      verify_horizon!(existing, incoming)

      [starts_at, ends_at]
    end

    def verify_horizon!(existing, incoming)
      old_horizon = existing.map(&:ends_at).max
      return unless old_horizon > Time.current
      return unless incoming.map(&:ends_at).max < old_horizon - HORIZON_TOLERANCE

      raise InsufficientCoverage, "l’horizon du nouveau guide recule"
    end

    def verify_channels!(existing, incoming)
      old_counts = existing.group_by { |entry| entry.guide_channel.external_id }
      new_counts = incoming.group_by(&:channel_id)
      old_counts.each do |channel, entries|
        minimum = [(entries.size * MINIMUM_CHANNEL_RATIO).ceil, 1].max
        next if new_counts.fetch(channel, []).size >= minimum

        raise InsufficientCoverage, "#{channel} : #{new_counts.fetch(channel, []).size} programmes " \
                                    "contre #{entries.size} dans la période commune"
      end
    end

    def compare(existing, incoming, starts_at, ends_at)
      old_keys = existing.to_set(&:fingerprint)
      new_keys = incoming.to_set { |entry| fingerprint(entry) }
      missing = existing.reject { |entry| new_keys.include?(entry.fingerprint) }.to_set(&:id)
      reviewed = review_changed_selections(existing, incoming, missing)

      comparison_result(old_keys, new_keys, reviewed, starts_at, ends_at)
    end

    def comparison_result(old_keys, new_keys, reviewed, starts_at, ends_at)
      Result.new(
        starts_at:, ends_at:, unchanged: (old_keys & new_keys).size,
        removed: (old_keys - new_keys).size, added: (new_keys - old_keys).size,
        renamed_intent_ids: reviewed.renamed_intent_ids,
        numbering_intent_ids: reviewed.numbering_intent_ids,
        missing_intent_ids: reviewed.missing_intent_ids
      )
    end

    def review_changed_selections(existing, incoming, missing)
      changed = existing.select { |entry| missing.include?(entry.id) }
      XmltvSelectedIntentReview.new(existing: changed, incoming:).call
    end

    def fingerprint(entry)
      XmltvObservationFingerprint.new(guide_source: @guide_source, programme: entry).call
    end

    def overlaps?(entry, starts_at, ends_at)
      entry.starts_at < ends_at && entry.ends_at > starts_at
    end
  end
end
