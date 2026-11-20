require 'time'

module Tv
  # Prepares a reviewable correction and rechecks both schedules under the scheduler lock.
  class RecordingScheduleCorrection
    class Conflict < StandardError; end

    PURPOSE = 'tv-recording-schedule-correction'.freeze

    def initialize(intent:, client: KaffeineDbus.new, lock: KaffeineScheduleLock.new)
      @intent = intent
      @client = client
      @lock = lock
    end

    def snapshot
      @intent.reload
      link = @intent.kaffeine_schedule_link
      validate_link!(link)
      schedules = @client.schedules
      live = schedules.find { |schedule| schedule.key == link.kaffeine_key }
      validate_live!(link, live)
      { link: link, schedules: schedules, live: live, vidb: vidb_attributes }
    end

    def preview(mode, input)
      current = snapshot
      desired = desired_attributes(mode, input, current)
      RecordingScheduleCorrectionAttributes.validate!(desired, current.fetch(:live))
      payload = { 'baseline' => baseline(current), 'mode' => mode,
                  'desired' => RecordingScheduleCorrectionAttributes.serializable(desired) }
      [current, desired, verifier.generate(payload, purpose: PURPOSE, expires_in: 15.minutes)]
    end

    def apply(token)
      payload = verifier.verified(token, purpose: PURPOSE)
      raise Conflict, 'Aperçu expiré. Recommence la correction.' unless payload.is_a?(Hash)

      @lock.synchronize { apply_preview(payload) }
    end

    private

    def apply_preview(payload)
      @intent.with_lock do
        current = snapshot
        unless payload.fetch('baseline') == baseline(current)
          raise Conflict, 'La programmation a changé. Recommence la correction.'
        end

        desired = RecordingScheduleCorrectionAttributes.deserialize(payload.fetch('desired'))
        RecordingScheduleCorrectionAttributes.validate!(desired, current.fetch(:live))
        persist(current, desired, payload.fetch('mode'))
      end
    end

    def validate_link!(link)
      return if @intent.status_selected? && link && !link.retired? && link.repeat_mask.zero?

      raise Conflict, 'La correction nécessite une programmation ponctuelle liée à vidb.'
    end

    def validate_live!(link, live)
      return if live&.repeat&.zero? && same_capture?(link, live)

      raise Conflict, 'Programmation Kaffeine manquante, répétée ou ambiguë.'
    end

    def same_capture?(link, live)
      live.name == link.name || [live.channel, live.starts_at] == [link.channel, link.starts_at]
    end

    def vidb_attributes
      RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
    rescue RecordingIntentScheduleAttributes::Unavailable
      nil
    end

    def desired_attributes(mode, input, current)
      case mode
      when 'vidb'
        current[:vidb] || raise(Conflict, 'Les paramètres de capture vidb sont incomplets.')
      when 'kaffeine'
        RecordingScheduleCorrectionAttributes.attributes(current.fetch(:live))
      when 'manual'
        RecordingScheduleCorrectionAttributes.manual_attributes(input)
      else
        raise Conflict, 'Choisis la source de la correction.'
      end
    end

    def persist(current, desired, mode)
      link = current.fetch(:link)
      live = current.fetch(:live)
      @intent.update!(capture_override: RecordingScheduleCorrectionAttributes.serializable(desired)) if mode != 'vidb'
      current_attributes = RecordingScheduleCorrectionAttributes.attributes(live)
      replacement = current_attributes == desired ? live : replace(current, desired)
      origin = replacement.key == live.key ? link.origin : :created_by_vidb
      KaffeineScheduleLinkAttachment.new(recording_intent: @intent, schedule: replacement, origin: origin,
                                         link: link).call
    end

    def replace(current, desired)
      live = current.fetch(:live)
      others = current.fetch(:schedules).reject { |schedule| schedule.key == live.key }
      if others.any? { |schedule| same_slot?(schedule, desired) }
        raise Conflict, 'Une autre capture occupe déjà ce créneau sur cette chaîne.'
      end

      MultiplexCapacityGuard.new(schedules: others, attributes: desired).check!
      KaffeineScheduleManager.new(client: @client).replace(live, **desired)
    end

    def same_slot?(schedule, desired)
      RecordingScheduleCorrectionAttributes.attributes(schedule).except(:name) == desired.except(:name)
    end

    def baseline(current)
      link = current.fetch(:link)
      live = current.fetch(:live)
      [@intent.id, @intent.updated_at.iso8601(6), link.id, link.updated_at.iso8601(6),
       live.key, RecordingScheduleCorrectionAttributes.schedule_snapshot(live),
       RecordingScheduleCorrectionAttributes.serializable(current[:vidb])]
    end

    def verifier
      Rails.application.message_verifier(PURPOSE)
    end
  end
end
