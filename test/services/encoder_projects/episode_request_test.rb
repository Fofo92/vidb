require 'test_helper'

class EncoderProjects::EpisodeRequestTest < ActiveSupport::TestCase
  test 'recognizes an episode in the source before the destination is named' do
    episode = EncoderProjects::EpisodeRequest.new(
      'source_paths' => ["/commun/to_be_cut/Cat's Eyes - S02 E01 - Un nouvel espoir.m2t"],
      'output_path' => '/videos/montage.mkv'
    )
    assert_equal "Cat's Eyes", episode.series
    assert_equal 2, episode.season
    assert_equal 1, episode.episode
    assert_equal 'Un nouvel espoir', episode.title
  end

  test 'recognizes a numbered destination without a source' do
    episode = EncoderProjects::EpisodeRequest.new('output_path' => '/videos/S04 E17 - Suite.mkv')
    assert_equal 17, episode.episode
    assert_equal 'Suite', episode.title
  end

  test 'films and episode zero do not enter the episode workflow' do
    refute EncoderProjects::EpisodeRequest.match?('output_path' => '/videos/Adieu Philippine.mkv')
    refute EncoderProjects::EpisodeRequest.match?('output_path' => '/videos/S02 E00 - Invalide.mkv')
  end

  test 'the natural French source name on the La stagiaire capture is an episode' do
    project = { 'source_paths' => ['/commun/to_be_cut/La stagiaire — Saison 9, épisode 6.m2t'],
                'output_path' => '/videos/montage.mkv' }
    assert EncoderProjects::EpisodeRequest.match?(project)
    request = EncoderProjects::EpisodeRequest.new(project)
    assert_equal ['La stagiaire', 9, 6, ''], [request.series, request.season, request.episode, request.title]
  end

  test 'natural French names preserve a supplied episode title' do
    ['La stagiaire — Saison 9, épisode 6 — Errance.m2t',
     'La stagiaire - saison 9 episode 6 - Errance.m2t',
     'La stagiaire - SAISON 9, ÉPISODE 6 : Errance.m2t'].each do |name|
      request = EncoderProjects::EpisodeRequest.new('source_paths' => ["/commun/#{name}"])
      assert_equal ['La stagiaire', 9, 6, 'Errance'], [request.series, request.season, request.episode, request.title]
    end
  end

  test 'natural French names keep explicit target overrides' do
    request = EncoderProjects::EpisodeRequest.new(
      'source_paths' => ['/commun/La stagiaire — Saison 9, épisode 6 — Errance.m2t'],
      'episode_target' => { 'season' => 9, 'episode' => 7 }
    )
    assert_equal ['La stagiaire', 9, 7, ''], [request.series, request.season, request.episode, request.title]
  end

  test 'a natural French name cannot select episode zero' do
    refute EncoderProjects::EpisodeRequest.match?('source_paths' => ['/commun/La stagiaire — Saison 9, épisode 0.m2t'])
  end

  test 'a typed episode identifies a generic source without changing file paths' do
    project = { 'source_paths' => ['/commun/capture.m2t'], 'output_path' => '/videos/montage.mkv' }
    selected = EncoderProjects::EpisodeRequest.with_query(project, 'La stagiaire - S09 E06 - Errance')
    request = EncoderProjects::EpisodeRequest.new(selected)
    assert_equal ['La stagiaire', 9, 6, 'Errance'], [request.series, request.season, request.episode, request.title]
    assert_equal project['source_paths'], selected['source_paths']
    assert_equal project['output_path'], selected['output_path']
    refute project.key?('episode_search')
  end

  test 'a typed correction replaces source numbers and a previous explicit target' do
    project = { 'source_paths' => ['/commun/Autre série - S01 E02.m2t'],
                'episode_target' => { 'season' => 1, 'episode' => 3 } }
    selected = EncoderProjects::EpisodeRequest.with_query(project, 'La stagiaire - S09 E06 - Errance')
    request = EncoderProjects::EpisodeRequest.new(selected)
    assert_equal ['La stagiaire', 9, 6, 'Errance'], [request.series, request.season, request.episode, request.title]
    refute selected.key?('episode_target')
    corrected = EncoderProjects::EpisodeRequest.new(selected.merge('episode_target' => { 'season' => 9, 'episode' => 7 }))
    assert_equal [9, 7, ''], [corrected.season, corrected.episode, corrected.title]
  end

  test 'an ordinary title or invalid episode leaves the project unchanged' do
    project = { 'source_paths' => ['/commun/capture.m2t'] }
    ['Impossible', 'La stagiaire - S09 E00', nil].each do |query|
      assert_same project, EncoderProjects::EpisodeRequest.with_query(project, query)
    end
  end

  test 'a typed title preserves punctuation including dots and slashes' do
    selected = EncoderProjects::EpisodeRequest.with_query({}, 'Série - S09 E06 - Errance... / suite')
    assert_equal 'Errance... / suite', EncoderProjects::EpisodeRequest.new(selected).title
  end
end
