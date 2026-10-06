require "test_helper"

module Tv
  class EquipeMultiplexCapacityTest < ActiveSupport::TestCase
    test "Equipe shares R10 and does not require a fifth tuner" do
      schedules = ["France 2", "CSTAR", "M6", "RMC STORY"].each_with_index.map do |name, index|
        schedule(name, index + 1)
      end

      ["L'Equipe", "L’Équipe", "L'Équipe"].each do |name|
        guard = MultiplexCapacityGuard.new(schedules:, attributes: attributes(name))
        assert_nothing_raised { guard.check! }
      end
    end

    test "Equipe contributes a known R10 to a real five multiplex conflict" do
      schedules = ["France 2", "CSTAR", "TF1", "L'Equipe"].each_with_index.map do |name, index|
        schedule(name, index + 1)
      end
      guard = MultiplexCapacityGuard.new(schedules:, attributes: attributes("M6"))

      error = assert_raises(MultiplexCapacityGuard::Warning) { guard.check! }
      assert_match(/5 multiplex pour 4 tuners/, error.message)
    end

    test "the guide catalogue Kaffeine name is recognized on R10" do
      name = ChannelCatalog.find("LEquipe21.fr").kaffeine_name

      assert_includes MultiplexCapacityGuard::MULTIPLEXES.fetch(10), name
    end

    private

    def attributes(channel)
      { name: "Programme", channel:, starts_at: Time.utc(2030, 1, 1, 18), duration_seconds: 3600, repeat: 0 }
    end

    def schedule(channel, key)
      KaffeineSchedule.new(key:, **attributes(channel), non_inactive: false)
    end
  end
end
