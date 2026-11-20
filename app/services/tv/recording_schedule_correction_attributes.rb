module Tv
  class RecordingScheduleCorrectionAttributes
    FIELDS = KaffeineScheduleManager::VERIFIED_ATTRIBUTES

    def self.attributes(schedule)
      FIELDS.to_h { |field| [field, schedule.public_send(field)] }
    end

    def self.serializable(attributes)
      return unless attributes

      attributes.stringify_keys.merge('starts_at' => attributes.fetch(:starts_at).utc.iso8601)
    end

    def self.deserialize(values)
      values.symbolize_keys.merge(starts_at: Time.iso8601(values.fetch('starts_at')))
    end

    def self.schedule_snapshot(schedule)
      serializable(attributes(schedule))
    end

    def self.manual_attributes(input)
      starts_at = local_time(input.fetch('starts_at', ''))
      ends_at = local_time(input.fetch('ends_at', ''))
      { name: input.fetch('name', '').strip, channel: input.fetch('channel', '').strip,
        starts_at: starts_at, duration_seconds: (ends_at - starts_at).to_i, repeat: 0 }
    end

    def self.local_time(value)
      wall = DateTime.strptime(value, '%Y-%m-%dT%H:%M')
      raise ArgumentError unless wall.strftime('%Y-%m-%dT%H:%M') == value

      Time.find_zone!('Europe/Paris').tzinfo.local_to_utc(wall, nil).to_time.utc
    rescue ArgumentError, TZInfo::PeriodNotFound, TZInfo::AmbiguousTime
      raise RecordingScheduleCorrection::Conflict, 'Horaire local invalide ou ambigu lors du changement d’heure.'
    end

    def self.validate!(desired, live)
      validate_window!(desired, live)
      name = desired.fetch(:name)
      unless name.length.between?(1, 300) && !name.match?(/[[:cntrl:]]/)
        raise RecordingScheduleCorrection::Conflict, 'Le titre doit comporter de 1 à 300 caractères imprimables.'
      end

      channel = desired.fetch(:channel)
      return if channel == live.channel || Channel.exists?(kaffeine_name: channel)

      raise RecordingScheduleCorrection::Conflict, 'Choisis le nom Kaffeine d’une chaîne connue de vidb.'
    end

    def self.validate_window!(desired, live)
      deadline = Time.current + KaffeineScheduleManager::REPLACEMENT_GUARD_SECONDS
      if [live.starts_at, desired.fetch(:starts_at)].min <= deadline
        raise RecordingScheduleCorrection::Conflict, 'La capture commence trop tôt ou a déjà commencé.'
      end
      return if desired.fetch(:duration_seconds).between?(1, 86_399)

      raise RecordingScheduleCorrection::Conflict, 'La capture doit durer plus de zéro seconde et moins de 24 heures.'
    end
  end
end
