require 'test_helper'

class EncoderProjects::SeriesCreationTest < ActiveSupport::TestCase
  setup do
    LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @candidate = { 'tmdb_id' => 4057, 'french_title' => 'Esprits criminels', 'original_title' => 'Criminal Minds',
                   'year' => 2005, 'source' => { 'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/tv/4057' } }
  end

  test 'reuses a matching qualified root instead of creating a duplicate' do
    creator = EncoderProjects::SeriesCreation.new(@candidate)
    root = creator.call
    assert_no_difference('Record.count') { assert_equal root.id, creator.call.id }
  end

  test 'refuses to turn an undetermined local record into a series without review' do
    Record.create!(french_title: 'Esprits criminels', year: 2005,
                   language_version: LanguageVersion.find_by!(short_name: 'IND'))
    assert_no_difference('Record.count') do
      assert_raises(ArgumentError) { EncoderProjects::SeriesCreation.new(@candidate).call }
    end
  end
end
