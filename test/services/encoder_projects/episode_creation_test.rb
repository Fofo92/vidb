require 'test_helper'

class EncoderProjects::EpisodeCreationTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @root = Record.create!(french_title: "Cat's Eyes", record_kind: 'series', language_version: language)
    @project = { 'source_paths' => ["/commun/to_be_cut/Cat's Eyes - S02 E01 - Un nouvel espoir.m2t"],
                 'output_path' => '/videos/montage.mkv' }
  end

  def prepare_episode
    EncoderProjects::EpisodeCreation.new.call(project: @project, series_id: @root.id,
                                              title: 'Un nouvel espoir', year: 2026,
                                              source: 'https://www.senscritique.com/serie/cat_s_eyes/62924447/S2')
  end

  test 'creates the missing hierarchy without claiming a physical copy and can be repeated' do
    episode = nil
    assert_difference 'Record.count', 2 do
      assert_no_difference('VideoAsset.count') { episode = prepare_episode }
    end
    assert_equal 'Saison 02', episode.parent.french_title
    assert_equal @root, episode.parent.parent
    assert_equal 1, episode.rank
    assert_equal false, episode.is_seen
    assert_equal false, episode.is_available
    assert_equal false, episode.is_recorded
    assert_nil episode.length_in_mn
    assert_empty episode.media
    assert_no_difference('Record.count') { assert_equal episode.id, prepare_episode.id }
  end

  test 'does not silently reclassify a record or replace an occupied episode rank' do
    @root.update!(record_kind: 'undetermined')
    assert_no_difference('Record.count') { assert_raises(ArgumentError) { prepare_episode } }
    @root.update!(record_kind: 'series')
    episode = prepare_episode
    episode.update!(french_title: 'Autre épisode')
    assert_raises(ArgumentError) { prepare_episode }
    assert_equal 'Autre épisode', episode.reload.french_title
  end
end
