require "test_helper"

module Tv
  class GuideSchedulingRisksTest < ActiveSupport::TestCase
    class Client
      attr_reader :calls

      def initialize(entries)
        @entries = entries
        @calls = 0
      end

      def schedules
        @calls += 1
        raise @entries if @entries.is_a?(Exception)

        @entries
      end
    end

    setup do
      source = GuideSource.create!(name: "risk_test", display_name: "Risk test")
      channel = Channel.create!(display_name: "M6", kaffeine_name: "M6")
      guide_channel = source.guide_channels.create!(external_id: "M6.fr", channel:)
      @programme = guide_channel.broadcast_observations.create!(
        fingerprint: "a" * 64, starts_at: Time.utc(2030, 1, 1, 18), ends_at: Time.utc(2030, 1, 1, 19),
        titles: [{ "value" => "Film" }]
      )
    end

    test "reports a fifth multiplex before selection without writing an intent" do
      client = Client.new(other_four)
      assert_no_difference("RecordingIntent.count") do
        result = GuideSchedulingRisks.new(client:).call([@programme])
        risk = result.fetch(:risks).fetch(@programme.id)
        assert_equal "conflict", risk.fetch(:level)
        assert_match(/5 multiplex pour 4 tuners/, risk.fetch(:message))
        assert_equal 4, risk.fetch(:details).size
        assert_equal({ title: "Enregistrement 1", channel: "France 2",
                       starts_at: "01/01 19:00", ends_at: "01/01 20:00" }, risk.fetch(:details).first)
      end
      assert_equal 1, client.calls
    end

    test "does not count a shared multiplex twice" do
      entries = other_four.take(3) + [schedule("Arte", 5)]
      result = GuideSchedulingRisks.new(client: Client.new(entries)).call([@programme])

      assert_nil result.fetch(:risks).fetch(@programme.id)
    end

    test "includes padding when identifying a conflict" do
      entries = other_four.map do |entry|
        entry.with(starts_at: Time.utc(2030, 1, 1, 17, 30), duration_seconds: 1500)
      end
      result = GuideSchedulingRisks.new(client: Client.new(entries)).call([@programme])

      assert_equal "conflict", result.fetch(:risks).fetch(@programme.id).fetch(:level)
      assert_match(/18:50/, result.fetch(:risks).fetch(@programme.id).fetch(:message))
    end

    test "does not overlap recordings ending exactly at the capture start" do
      entries = other_four.map do |entry|
        entry.with(starts_at: Time.utc(2030, 1, 1, 17), duration_seconds: 3000)
      end
      result = GuideSchedulingRisks.new(client: Client.new(entries)).call([@programme])

      assert_nil result.fetch(:risks).fetch(@programme.id)
    end

    test "reports an unknown active channel as uncertainty" do
      result = GuideSchedulingRisks.new(client: Client.new([schedule("Inconnue", 1)])).call([@programme])

      assert_equal "unknown", result.fetch(:risks).fetch(@programme.id).fetch(:level)
    end

    test "does not assume a past repeating schedule cannot recur" do
      repeated = schedule("TF1", 1).with(starts_at: Time.utc(2029, 1, 1, 18), repeat: 1)
      result = GuideSchedulingRisks.new(client: Client.new([repeated])).call([@programme])

      assert_equal "unknown", result.fetch(:risks).fetch(@programme.id).fetch(:level)
    end

    test "reports unavailability instead of claiming that capacity is sufficient" do
      client = Client.new(KaffeineCommandRunner::CommandError.new("No session"))
      result = GuideSchedulingRisks.new(client:).call([@programme])

      assert_not result.fetch(:available)
      assert_empty result.fetch(:risks)
    end

    test "reads Kaffeine only once for all programmes and exposes the elapsed time" do
      client = Client.new([])
      result = GuideSchedulingRisks.new(client:).call([@programme, @programme])

      assert_equal 1, client.calls
      assert_operator result.fetch(:elapsed_ms), :>=, 0
    end

    test "preserves the margins of a previously cancelled selection without changing it" do
      intent = RecordingIntent.create!(broadcast_observation: @programme, status: "cancelled",
                                       effective_padding_before_seconds: 1800)
      entries = other_four.map do |entry|
        entry.with(starts_at: Time.utc(2030, 1, 1, 17), duration_seconds: 2400)
      end
      result = GuideSchedulingRisks.new(client: Client.new(entries)).call([@programme.reload])

      assert_equal "conflict", result.fetch(:risks).fetch(@programme.id).fetch(:level)
      assert intent.reload.status_cancelled?
    end

    private

    def other_four
      ["France 2", "CSTAR", "TF1", "RMC STORY"].each_with_index.map { |name, index| schedule(name, index + 1) }
    end

    def schedule(channel, key)
      KaffeineSchedule.new(key:, channel:, name: "Enregistrement #{key}", starts_at: Time.utc(2030, 1, 1, 18),
                           duration_seconds: 3600, repeat: 0, non_inactive: false)
    end
  end
end
