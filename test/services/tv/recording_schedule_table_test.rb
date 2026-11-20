require 'test_helper'

class Tv::RecordingScheduleTableTest < ActiveSupport::TestCase
  test 'shows recent Kaffeine-only schedules newest first and hides ended captures by default' do
    now = Time.utc(2026, 11, 20, 12)
    schedules = [schedule(1, now - 2.hours), schedule(2, now + 1.hour), schedule(3, now + 2.hours)]
    client = Struct.new(:schedules).new(schedules)
    travel_to now do
      rows = build_table(client, {}).call
      assert_equal [3, 2], rows.map { |row| row.schedule.key }
      assert rows.all? { |row| row.state == 'kaffeine_only' }

      filtered = build_table(client, { history: '1', q: 'émission 1' }).call
      assert_equal [1], filtered.map { |row| row.schedule.key }
    end
  end

  private

  def schedule(key, starts_at)
    Tv::KaffeineSchedule.new(key: key, name: "Émission #{key}", channel: 'Arte', starts_at: starts_at,
                             duration_seconds: 3600, repeat: 0, non_inactive: false)
  end

  def build_table(client, filters)
    Tv::RecordingScheduleTable.new(intents: [], filters: filters, title: ->(_intent) {}, client: client)
  end
end
