require 'test_helper'

class Tv::RecordingScheduleCorrectionTest < ActiveSupport::TestCase
  class Client
    attr_reader :schedules

    def initialize(schedule)
      @schedules = [schedule]
    end

    def create_schedule(**attributes)
      @schedules << Tv::KaffeineSchedule.new(key: 99, non_inactive: false, **attributes)
      99
    end

    def remove_schedule(key)
      @schedules.reject! { |schedule| schedule.key == key }
    end
  end

  setup do
    source = Tv::GuideSource.create!(name: 'correction', display_name: 'Test')
    channel = Tv::Channel.create!(display_name: 'Arte', kaffeine_name: 'Arte')
    guide = source.guide_channels.create!(external_id: 'arte', channel: channel)
    start = Time.current.change(usec: 0) + 1.day
    observation = guide.broadcast_observations.create!(
      fingerprint: 'b' * 64, titles: [{ 'value' => 'Film' }], starts_at: start, ends_at: start + 1.hour
    )
    @intent = Tv::RecordingIntent.create!(broadcast_observation: observation)
    attributes = Tv::RecordingIntentScheduleAttributes.new(recording_intent: @intent).call
    original = Tv::KaffeineSchedule.new(key: 3, **attributes, non_inactive: false)
    Tv::KaffeineScheduleLink.attach!(recording_intent: @intent, schedule: original, origin: :created_by_vidb)
    live = original.with(starts_at: original.starts_at + 5.minutes)
    @client = Client.new(live)
    @correction = Tv::RecordingScheduleCorrection.new(intent: @intent, client: @client)
  end

  test 'adopts the live capture in vidb while preserving the broadcast' do
    programme_start = @intent.programme_starts_at
    live = @client.schedules.sole
    _, _, token = @correction.preview('kaffeine', {})
    assert_empty @intent.reload.capture_override

    @correction.apply(token)
    assert_equal programme_start, @intent.reload.programme_starts_at
    assert_equal live.starts_at, @intent.capture_starts_at
    assert_equal [live], @client.schedules
    assert @intent.kaffeine_schedule_link.matches?(live)
  end

  test 'applies vidb to Kaffeine and refuses a stale confirmation' do
    _, desired, token = @correction.preview('vidb', {})
    @correction.apply(token)
    live = @client.schedules.sole
    assert_equal desired[:name], live.name
    assert_equal desired[:starts_at], live.starts_at
    assert @intent.reload.kaffeine_schedule_link.matches?(live)
    assert_raises(Tv::RecordingScheduleCorrection::Conflict) { @correction.apply(token) }
  end

  test 'manual edits adopt the confirmed capture in both systems' do
    starts = (@intent.programme_starts_at + 2.hours).in_time_zone('Europe/Paris')
    input = { 'name' => 'Titre manuel', 'channel' => 'Arte',
              'starts_at' => starts.strftime('%Y-%m-%dT%H:%M'),
              'ends_at' => (starts + 1.hour).strftime('%Y-%m-%dT%H:%M') }
    _, desired, token = @correction.preview('manual', input)
    @correction.apply(token)
    live = @client.schedules.sole
    assert_equal 'Titre manuel', live.name
    assert_equal desired[:starts_at], @intent.reload.capture_starts_at
    assert @intent.kaffeine_schedule_link.matches?(live)
  end
end
