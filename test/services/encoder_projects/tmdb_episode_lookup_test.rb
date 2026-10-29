require 'test_helper'
require 'minitest/mock'

class EncoderProjects::TmdbEpisodeLookupTest < ActiveSupport::TestCase
  Link = Struct.new(:evidence, :external_series_id, :local_season_number, :local_episode_number,
                    :external_season_number, :external_episode_number, :external_episode_id)
  Numbers = Struct.new(:season, :episode)

  class Links
    def initialize(rows)
      @rows = rows
    end

    def where(**)
      self
    end

    def to_a
      @rows
    end
  end

  test 'reuses a reviewed cross season correspondence only for the matching local episode and series' do
    link = Link.new({ 'explicit_episode_mapping' => true }, 42083, 12, 11, 14, 2, 987)
    subtree = Object.new
    subtree.define_singleton_method(:select) { |_| [] }
    series = Struct.new(:subtree).new(subtree)
    lookup = EncoderProjects::TmdbEpisodeLookup.new(client: nil, page: nil, links: Links.new([link]), warnings: [])
    reference = lookup.send(:stored_reference, 42083, series, Numbers.new(12, 11))
    assert_equal({ 'season' => 14, 'episode' => 2, 'episode_id' => 987 }, reference)
    assert_nil lookup.send(:stored_reference, 42083, series, Numbers.new(12, 10))
    assert_nil lookup.send(:stored_reference, 42084, series, Numbers.new(12, 11))
  end
end
