require 'test_helper'

module EncoderProjects
  class TmdbGenericEpisodeTitleMappingTest < ActiveSupport::TestCase
    test 'uses one-to-one numbering when TMDB still exposes generic episode titles' do
      rows = ['Épisode 1', 'Épisode 2'].each_with_index.map do |title, index|
        {
          'tmdb_episode_id' => 100 + index,
          'episode_number' => index + 1,
          'title_fr' => title,
          'title_original' => title,
          'reference_runtime_minutes' => 55
        }
      end
      local_entries = ['Roméo', 'Une autre disparition'].each_with_index.to_h do |title, index|
        [index + 1, { 'title' => title, 'source' => {} }]
      end

      result = EpisodeEditionMapping.new.call(rows, local_entries)

      assert_equal ['Roméo', 'Une autre disparition'], result.pluck('title_fr')
      external_numbers = result.map do |row|
        row.fetch('external_parts').pluck('episode_number')
      end
      assert_equal [[1], [2]], external_numbers
    end
  end
end
