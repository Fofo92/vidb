module Tv
  # Classifies changes to selected future programmes across two XMLTV snapshots.
  class XmltvSelectedIntentReview
    Result = Data.define(:renamed_intent_ids, :numbering_intent_ids, :missing_intent_ids)

    def initialize(existing:, incoming:)
      @existing = existing
      @by_slot = incoming.group_by do |entry|
        channel = entry.respond_to?(:channel_id) ? entry.channel_id : entry.guide_channel.external_id
        [channel, entry.starts_at, entry.ends_at]
      end
    end

    def call
      selected = selected_intents
      groups = { equivalent: [], numbering: [], missing: [] }
      @existing.each do |entry|
        intent = selected[entry.id]
        next unless intent && intent.capture_ends_at > Time.current

        groups.fetch(classify_entry(entry)) << intent.id
      end
      Result.new(groups[:equivalent], groups[:numbering], groups[:missing])
    end

    def classify_entry(entry)
      candidates = @by_slot.fetch([entry.guide_channel.external_id, entry.starts_at, entry.ends_at], [])
      return :equivalent if candidates.any? { |candidate| equivalent?(entry, candidate) }
      return :numbering if candidates.any? { |candidate| numbering_changed?(entry, candidate) }

      :missing
    end

    private

    def selected_intents
      RecordingIntent.status_selected
                     .where(broadcast_observation_id: @existing.map(&:id))
                     .index_by(&:broadcast_observation_id)
    end

    def equivalent?(first, second)
      return false unless title(first) == title(second) && episode(first) == episode(second)
      return true unless episode(first)

      subtitle(first) == subtitle(second)
    end

    def numbering_changed?(first, second)
      same_titles?(first, second) && subtitle(first).present? &&
        episode(first).present? && episode(second).present? && episode(first) != episode(second)
    end

    def same_titles?(first, second)
      title(first) == title(second) && subtitle(first) == subtitle(second)
    end

    def title(entry)
      localized(entry.titles).to_s.sub(/\s+-\s+Saison\s+\d+\z/i, "").squish.downcase
    end

    def subtitle(entry)
      value = localized(entry.subtitles).to_s.squish.downcase
      value.match?(/\A[ée]pisode\s+\d+\z/) ? "" : value
    end

    def episode(entry)
      number = entry.episode_numbers.find { |item| field(item, :system) == "xmltv_ns" }
      match = field(number, :value)&.match(/\A(\d+)\.(\d+)\./)
      match&.captures&.map(&:to_i)
    end

    def localized(entries)
      entry = entries.find { |item| field(item, :language) == "fr" } || entries.first
      field(entry, :value)
    end

    def field(entry, key)
      entry && (entry[key] || entry[key.to_s])
    end
  end
end
