module Tv
  # Reviews selected captures whose original observation left the displayed guide.
  class GuideSelectionAlerts
    Result = Data.define(:by_programme, :unplaced, :rename_by_programme, :linked_intents_by_programme)

    def initialize(guide_source:, date:, programmes:)
      @guide_source = guide_source
      @date = date
      @programmes = programmes
      @by_slot = programmes.group_by do |programme|
        [programme.guide_channel_id, programme.starts_at, programme.ends_at]
      end
    end

    def call
      return Result.new({}, [], {}, {}) unless @guide_source

      alerts = {}
      unplaced = []
      rename_candidates = {}
      linked_intents = {}
      obsolete_intents.group_by { |intent| slot_key(intent.broadcast_observation) }.each_value do |intents|
        place_intents(intents, alerts, unplaced, rename_candidates, linked_intents)
      end
      Result.new(alerts, unplaced, rename_candidates, linked_intents)
    end

    private

    def obsolete_intents
      current_ids = @programmes.map(&:id)
      RecordingIntent.status_selected
                     .joins(:kaffeine_schedule_link, broadcast_observation: :guide_channel)
                     .where(tv_guide_channels: { guide_source_id: @guide_source.id })
                     .where("programme_starts_at < ? AND programme_ends_at > ?", day_end, day_start)
                     .where.not(broadcast_observation_id: current_ids)
                     .includes(:kaffeine_schedule_link, broadcast_observation: :guide_channel)
                     .select { |intent| intent.capture_ends_at > Time.current }
    end

    def place_intents(intents, alerts, unplaced, rename_candidates, linked_intents)
      slot = @by_slot.fetch(slot_key(intents.first.broadcast_observation), [])
      if slot.one? && intents.one? && !slot.first.recording_intent&.status_selected?
        place_intent(intents.first, slot.first, alerts, rename_candidates, linked_intents)
      elsif slot.empty?
        intents.each { |intent| unplaced << missing_warning(intent) }
      end
    end

    def place_intent(intent, programme, alerts, rename_candidates, linked_intents)
      linked_intents[programme.id] = intent
      link = intent.kaffeine_schedule_link
      name = ProgrammeDisplayName.call(programme).to_s
      return if name.squish == link.name.to_s.squish

      alerts[programme.id] = [warning(intent, programme)]
      rename_candidates[programme.id] = [intent] if link.origin_created_by_vidb? && name.present?
    end

    def warning(intent, programme)
      link = intent.kaffeine_schedule_link
      old = intent.broadcast_observation
      "Sélection vidb #{intent.id}, Kaffeine n° #{link.kaffeine_key}. " \
        "Intitulé Kaffeine différent du nouveau guide.\n" \
        "Ancien guide (Kaffeine) : #{description(old, link.name)}.\n" \
        "Nouveau guide : #{description(programme, ProgrammeDisplayName.call(programme))}."
    end

    def missing_warning(intent)
      link = intent.kaffeine_schedule_link
      "Sélection vidb #{intent.id}, Kaffeine n° #{link.kaffeine_key}.\n" \
        "Ancien guide (Kaffeine) : #{description(intent.broadcast_observation, link.name)}.\n" \
        "Nouveau guide : aucune plage aux mêmes horaires. L’import ne modifie pas Kaffeine."
    end

    def description(programme, name)
      zone = Time.find_zone!("Europe/Paris")
      starts_at = programme.starts_at.in_time_zone(zone).strftime("%d/%m %H:%M")
      ends_at = programme.ends_at.in_time_zone(zone).strftime("%d/%m %H:%M")
      "#{name} (#{starts_at}–#{ends_at})"
    end

    def slot_key(programme)
      [programme.guide_channel_id, programme.starts_at, programme.ends_at]
    end

    def day_start
      Time.find_zone!("Europe/Paris").local(@date.year, @date.month, @date.day)
    end

    def day_end
      tomorrow = @date.next_day
      Time.find_zone!("Europe/Paris").local(tomorrow.year, tomorrow.month, tomorrow.day)
    end
  end
end
