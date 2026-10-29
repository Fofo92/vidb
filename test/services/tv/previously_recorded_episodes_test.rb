require 'test_helper'
require 'minitest/mock'

class Tv::PreviouslyRecordedEpisodesTest < ActiveSupport::TestCase
  Programme = Struct.new(:id, :titles, :episode_numbers, :starts_at)
  Intent = Struct.new(:broadcast_observation, :programme_starts_at, :programme_ends_at)

  class Confirmed
    def initialize(rows)
      @rows = rows
    end

    def includes(*)
      @rows
    end
  end

  class IntentQuery
    def initialize(rows)
      @rows = rows
    end

    def not(**conditions)
      raise 'Confirmation filter missing' unless conditions == { recording_verified_at: nil }

      Confirmed.new(@rows)
    end
  end

  test 'matches normalized history without depending on a live schedule link or selection status' do
    old = Programme.new(1, [{ 'value' => 'Joséphine, ange gardien - Saison 12' }],
                        [{ 'system' => 'xmltv_ns', 'value' => '11.10.' }], Time.utc(2026, 10, 24, 18))
    current = Programme.new(2, [{ 'value' => 'Joséphine, ange gardien' }], old.episode_numbers,
                            Time.utc(2026, 10, 29, 18))
    verified = Intent.new(old, old.starts_at, old.starts_at + 90.minutes)
    query = IntentQuery.new([verified])
    Tv::RecordingIntent.stub(:where, -> { query }) do
      result = Tv::PreviouslyRecordedEpisodes.new.call([current])
      assert_equal verified, result.fetch(2)
      current.episode_numbers = [{ 'system' => 'xmltv_ns', 'value' => '11.11.' }]
      assert_empty Tv::PreviouslyRecordedEpisodes.new.call([current])
    end
  end
end
