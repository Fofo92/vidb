module Tv
  # Reviews selected captures whose original observation left the displayed guide.
  class GuideSelectionAlerts
    Result = Data.define(:by_programme, :unplaced)

    def initialize(guide_source:, date:, programmes:)
      @guide_source = guide_source
      @date = date
      @programmes = programmes
      @by_slot = programmes.group_by do |programme|
        [programme.guide_channel_id, programme.starts_at, programme.ends_at]
      end
    end

    def call
      return Result.new({}, []) unless @guide_source

      alerts = Hash.new { |hash, key| hash[key] = [] }
      unplaced = []
      reviewer = XmltvSelectedIntentReview.new(existing: [], incoming: @programmes)
      obsolete_intents.each { |intent| classify_intent(intent, reviewer, alerts, unplaced) }
      Result.new(alerts, unplaced)
    end

    private

    def obsolete_intents
      current_ids = @programmes.map(&:id)
      RecordingIntent.status_selected
                     .joins(broadcast_observation: :guide_channel)
                     .where(tv_guide_channels: { guide_source_id: @guide_source.id })
                     .where("programme_starts_at < ? AND programme_ends_at > ?", day_end, day_start)
                     .where.not(broadcast_observation_id: current_ids)
                     .includes(broadcast_observation: :guide_channel)
    end

    def classify_intent(intent, reviewer, alerts, unplaced)
      return if intent.capture_ends_at <= Time.current

      old = intent.broadcast_observation
      classification = reviewer.classify_entry(old)
      return if classification == :equivalent

      slot = @by_slot.fetch([old.guide_channel_id, old.starts_at, old.ends_at], [])
      message = warning(intent, slot, classification)
      slot.empty? ? unplaced << message : slot.each { |programme| alerts[programme.id] << message }
    end

    def warning(intent, slot, classification)
      old = intent.broadcast_observation
      prefix = "Sélection vidb #{intent.id}.\nAncien guide : #{description(old)}."
      missing = "#{prefix}\nNouveau guide : aucune plage aux mêmes horaires. Kaffeine inchangé."
      return missing if slot.empty?

      comparison = "#{prefix}\nNouveau guide : #{description(slot.first)}."
      if classification == :numbering
        return "#{comparison} Numérotation discordante ; vérifier le titre de l’épisode. Kaffeine inchangé."
      end

      "#{comparison} Intitulé différent ; vérifier la sélection. Kaffeine inchangé."
    end

    def description(programme)
      zone = Time.find_zone!("Europe/Paris")
      starts_at = programme.starts_at.in_time_zone(zone).strftime("%d/%m %H:%M")
      ends_at = programme.ends_at.in_time_zone(zone).strftime("%d/%m %H:%M")
      "#{ProgrammeDisplayName.call(programme)} (#{starts_at}–#{ends_at})"
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
