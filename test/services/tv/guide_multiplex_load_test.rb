require "test_helper"

module Tv
  class GuideMultiplexLoadTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(name: "multiplex_test", display_name: "Multiplex test")
      @date = Date.new(2030, 1, 1)
      @zone = Time.find_zone!("Europe/Paris")
      @sequence = 0
    end

    test "counts simultaneous recordings on the same multiplex once" do
      first = intent("M6", 18, 19)
      second = intent("Arte", 18, 19)
      active = load_segments.find { |segment| segment.captures.size == 2 }

      assert_equal [4], active.multiplexes
      assert_equal [first.id, second.id], active.captures.map(&:intent_id)
    end

    test "distinguishes all five known multiplexes" do
      ["France 2", "CSTAR", "M6", "TF1", "RMC STORY"].each { |name| intent(name, 18, 19) }
      active = load_segments.find { |segment| segment.captures.size == 5 }

      assert_equal [1, 2, 4, 6, 10], active.multiplexes
      assert_empty active.unknown_channels
    end

    test "includes effective padding rather than requested padding" do
      selected = intent("TF1", 18, 19)
      selected.update!(effective_padding_before_seconds: 120, effective_padding_after_seconds: 180,
                       requested_padding_before_seconds: 600)
      active = load_segments.find { |segment| segment.captures.any? }

      assert_equal 1078.0, active.start_minute
      assert_equal 1143.0, active.end_minute
    end

    test "reports unknown channels without counting them as known multiplexes" do
      intent("TF1", 18, 19)
      intent("Chaîne inconnue", 18, 19)
      active = load_segments.find { |segment| segment.captures.size == 2 }

      assert_equal [6], active.multiplexes
      assert_equal ["Chaîne inconnue"], active.unknown_channels
    end

    test "does not overlap captures whose end and start are identical" do
      intent("TF1", 18, 19, padding: 0)
      intent("M6", 19, 20, padding: 0)

      assert_equal 1, load_segments.map { |segment| segment.multiplexes.size }.max
    end

    test "clips captures to midnight and includes padding from the following day" do
      selected = intent("TF1", 23, 24, padding: 0)
      selected.update!(programme_starts_at: @zone.local(2030, 1, 2, 0, 5),
                       programme_ends_at: @zone.local(2030, 1, 2, 1), effective_padding_before_seconds: 600)
      active = load_segments.find { |segment| segment.captures.any? }

      assert_equal 1435.0, active.start_minute
      assert_equal 1440.0, active.end_minute
    end

    test "ignores cancelled selections and records outside the day" do
      intent("TF1", 18, 19).update!(status: "cancelled")
      selected = intent("M6", 18, 19)
      selected.update!(programme_starts_at: @zone.local(2030, 1, 3, 18),
                       programme_ends_at: @zone.local(2030, 1, 3, 19))

      assert load_segments.all? { |segment| segment.captures.empty? }
    end

    test "keeps seconds in capture boundaries" do
      intent("TF1", 18, 19).update!(effective_padding_before_seconds: 30)
      active = load_segments.find { |segment| segment.captures.any? }

      assert_equal 1079.5, active.start_minute
    end

    test "uses the real length of daylight saving transition days" do
      spring = GuideMultiplexLoad.new(date: Date.new(2026, 3, 29), guide_source: @source).call
      autumn = GuideMultiplexLoad.new(date: Date.new(2026, 10, 25), guide_source: @source).call

      assert_equal 1380.0, spring.last.end_minute
      assert_equal 1500.0, autumn.last.end_minute
    end

    private

    def load_segments
      GuideMultiplexLoad.new(date: @date, guide_source: @source).call
    end

    def intent(name, starts_hour, ends_hour, padding: 600)
      @sequence += 1
      channel = Channel.find_or_create_by!(display_name: name) { |entry| entry.kaffeine_name = name }
      guide_channel = @source.guide_channels.find_or_create_by!(external_id: "channel#{channel.id}", channel:)
      observation = guide_channel.broadcast_observations.create!(
        fingerprint: format("%064x", @sequence), starts_at: @zone.local(2030, 1, 1, starts_hour),
        ends_at: @zone.local(2030, 1, 1) + ends_hour.hours,
        titles: [{ "value" => "Programme #{@sequence}" }]
      )
      RecordingIntent.create!(broadcast_observation: observation,
                              effective_padding_before_seconds: padding, effective_padding_after_seconds: padding)
    end
  end
end
