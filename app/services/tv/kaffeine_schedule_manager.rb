module Tv
  # Verifies that schedule changes are reflected exactly by Kaffeine.
  class KaffeineScheduleManager
    class Error < StandardError; end
    class VerificationError < Error; end
    class TooLateToReplace < Error; end

    REPLACEMENT_GUARD_SECONDS = 120
    VERIFIED_ATTRIBUTES = %i[name channel starts_at duration_seconds repeat].freeze

    def initialize(
      client:,
      clock: -> { Time.now },
      replacement_guard_seconds: REPLACEMENT_GUARD_SECONDS
    )
      @client = client
      @clock = clock
      @replacement_guard_seconds = replacement_guard_seconds
    end

    def create(**attributes)
      key = @client.create_schedule(**attributes)
      schedule = @client.schedules.find { |entry| entry.key == key }

      return schedule if matching?(schedule, attributes)

      raise VerificationError, verification_error_message(key)
    end

    def remove(expected)
      verify_before_removal(expected)

      @client.remove_schedule(expected.key)

      verify_after_removal(expected.key)
    end

    def replace(expected, **attributes)
      verify_replacement_deadline(expected)

      replacement = create(**attributes)
      remove(expected)

      replacement
    end

    private

    def verify_before_removal(expected)
      current = @client.schedules.find { |entry| entry.key == expected.key }
      attributes = verified_attributes(expected)

      return if matching?(current, attributes)

      raise VerificationError, verification_error_message(expected.key)
    end

    def verify_after_removal(key)
      return unless @client.schedules.any? { |entry| entry.key == key }

      raise VerificationError, removal_error_message(key)
    end

    def verified_attributes(schedule)
      VERIFIED_ATTRIBUTES.to_h do |attribute|
        [attribute, schedule.public_send(attribute)]
      end
    end

    def removal_error_message(key)
      format(
        "Kaffeine schedule %<key>d still exists after removal",
        key:
      )
    end

    def matching?(schedule, attributes)
      return false unless schedule

      VERIFIED_ATTRIBUTES.all? do |attribute|
        schedule.public_send(attribute) == attributes.fetch(attribute)
      end
    end

    def verification_error_message(key)
      format(
        "Kaffeine schedule %<key>d could not be verified",
        key:
      )
    end

    def verify_replacement_deadline(expected)
      deadline = expected.starts_at - @replacement_guard_seconds

      return if @clock.call < deadline

      raise TooLateToReplace, replacement_deadline_message(expected)
    end

    def replacement_deadline_message(expected)
      format(
        "schedule %<key>d is too close to its start time to replace",
        key: expected.key
      )
    end
  end
end
