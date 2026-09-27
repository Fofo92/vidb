module Tv
  class KaffeineScheduleLock
    class Busy < StandardError; end

    LOCK_NAMESPACE = 1_986_618_466
    LOCK_KEY = 1

    def synchronize
      ActiveRecord::Base.transaction do
        acquired = ActiveRecord::Base.connection.select_value(
          "SELECT pg_try_advisory_xact_lock(#{LOCK_NAMESPACE}, #{LOCK_KEY})"
        )
        raise Busy, "another Kaffeine scheduling operation is in progress" unless acquired

        yield
      end
    end
  end
end
