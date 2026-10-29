require 'test_helper'

class Tv::AcquiredEpisodesTest < ActiveSupport::TestCase
  test 'uses the library first and only inspects captures for the remaining programmes' do
    programme = Struct.new(:id, :titles, :episode_numbers)
    programmes = [7, 8].map do |id|
      programme.new(id, [{ 'value' => 'Joséphine' }], [{ 'system' => 'xmltv_ns', 'value' => '11.10.' }])
    end
    library = Object.new
    library.define_singleton_method(:call) { |_| { 7 => :encoded } }
    captures = Object.new
    observed = nil
    captures.define_singleton_method(:call) { |items| observed = items.map(&:id); { 8 => :quarantined } }
    result = Tv::AcquiredEpisodes.new(library: library, captures: captures).call(programmes)
    assert_equal({ 7 => :encoded, 8 => :quarantined }, result)
    assert_equal [8], observed
  end
end
