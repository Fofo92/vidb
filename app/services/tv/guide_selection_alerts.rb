module Tv
  # Reviews selected captures whose original observation left the displayed guide.
  class GuideSelectionAlerts
    Result = Data.define(:by_programme, :unplaced, :rename_by_programme)

    def initialize(guide_source:, date:, programmes:)
      @guide_source = guide_source
      @date = date
      @programmes = programmes
      @by_slot = programmes.group_by do |programme|
        [programme.guide_channel_id, programme.starts_at, programme.ends_at]
      end
    end

    def call
      return Result.new({}, [], {}) unless @guide_source

      alerts = Hash.new { |hash, key| hash[key] = [] }
      unplaced = []
      rename_candidates = Hash.new { |hash, key| hash[key] = [] }
      reviewer = XmltvSelectedIntentReview.new(existing: [], incoming: @programmes)
      obsolete_intents.each do |intent|
        classify_intent(intent, reviewer, alerts, unplaced, rename_candidates)
      end
      Result.new(alerts, unplaced, rename_candidates)
    end

    private

    def obsolete_intents
      current_ids = @programmes.map(&:id)
      RecordingIntent.status_selected
                     .joins(broadcast_observation: :guide_channel)
                     .where(tv_guide_channels: { guide_source_id: @guide_source.id })
                     .where("programme_starts_at < ? AND programme_ends_at > ?", day_end, day_start)
                     .where.not(broadcast_observation_id: current_ids)
                     .includes(:kaffeine_schedule_link, broadcast_observation: :guide_channel)
    end

    def classify_intent(intent, reviewer, alerts, unplaced, rename_candidates)
      return if intent.capture_ends_at <= Time.current

      old = intent.broadcast_observation
      classification = reviewer.classify_entry(old)
      return if classification == :equivalent

      slot = @by_slot.fetch([old.guide_channel_id, old.starts_at, old.ends_at], [])
      message = warning(intent, slot, classification)
      return unplaced << message if slot.empty?

      add_alerts(slot, message, intent, alerts, rename_candidates)
    end

    def add_alerts(slot, message, intent, alerts, rename_candidates)
      slot.each do |programme|
        alerts[programme.id] << message
        add_rename_candidate(rename_candidates, programme, intent)
      end
    end

    def add_rename_candidate(candidates, programme, intent)
      link = intent.kaffeine_schedule_link
      return unless link&.origin_created_by_vidb?

      name = ProgrammeDisplayName.call(programme)
      candidates[programme.id] << intent if name.present? && name != link.name
    end

    def warning(intent, slot, classification)
      old = intent.broadcast_observation
      prefix = "Sélection vidb #{intent.id}.\nAncien guide : #{description(old)}."
      missing = "#{prefix}\nNouveau guide : aucune plage aux mêmes horaires. L’import ne modifie pas Kaffeine."
      return missing if slot.empty?

      comparison = "#{prefix}\nNouveau guide : #{description(slot.first)}."
      return numbering_message(comparison) if classification == :numbering

      "#{comparison} #{difference_message(old, slot.first)}"
    end

    def numbering_message(comparison)
      "#{comparison} Numérotation discordante ; vérifier le titre de l’épisode."
    end

    def difference_message(old, current)
      old_name = ProgrammeDisplayName.call(old).to_s.squish
      new_name = ProgrammeDisplayName.call(current).to_s.squish
      return "Intitulé différent ; vérifier la sélection." unless old_name == new_name

      old_subtitle = ProgrammeDisplayName.subtitle(old)
      new_subtitle = ProgrammeDisplayName.subtitle(current)
      return "Sous-titre XMLTV : «#{old_subtitle}» → «#{new_subtitle}»." unless old_subtitle == new_subtitle

      "Métadonnées XMLTV différentes ; intitulé affiché identique."
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
