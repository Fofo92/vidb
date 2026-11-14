require 'test_helper'

class RecordPosters::GenericEpisodeTitleTest < ActiveSupport::TestCase
  test 'numeric and spelled episode labels retain their actual number' do
    { 'Episode One' => 1, 'Episode Two' => 2, 'Episode Nineteen' => 19,
      'Épisode #20' => 20, 'Episode Twenty-One' => 21, 'Episode forty two' => 42,
      'Episode ninety nine' => 99, 'Episode 104' => 104,
      'Teil 1' => 1, 'Teil 2' => 2, 'Teil 12' => 12 }.each do |title, number|
      assert_equal number, RecordPosters::GenericEpisodeTitle.number(title)
    end
  end

  test 'informative titles are never treated as generic labels' do
    [nil, '', 'Dark Descent', 'Episode of War', 'Episode One More Time', 'Part One',
     'Teil One', 'Teil des Lebens', 'Teil 1 der Geschichte'].each do |title|
      assert_nil RecordPosters::GenericEpisodeTitle.number(title)
    end
  end
end
