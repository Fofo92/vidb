require 'test_helper'

class EncoderProjects::ReviewedEpisodeReferenceTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    root = Record.create!(french_title: 'Joséphine', record_kind: 'series', language_version: language)
    season = root.children.create!(french_title: 'Saison 12', record_kind: 'season', rank: 12, language_version: language)
    @episode = season.children.create!(french_title: 'Chasse aux fantômes', record_kind: 'episode', rank: 11,
                                       language_version: language, is_seen: true)
    @candidate = { 'tmdb_episode_reference' => { 'series_id' => 42083, 'season' => 14, 'episode' => 2,
                                                'episode_id' => 987 },
                   'source' => { 'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/tv/42083/season/14/episode/2' } }
  end

  test 'requires an explicit confirmation even when a form is submitted directly' do
    assert_raises(ArgumentError) { EncoderProjects::ReviewedEpisodeReference.validate!(@candidate, {}) }
    EncoderProjects::ReviewedEpisodeReference.validate!(@candidate, 'confirm_tmdb_episode_mapping' => '1')
    EncoderProjects::ReviewedEpisodeReference.validate!({}, {})
  end

  test 'persists one correspondence without moving the episode or changing its state' do
    service = EncoderProjects::ReviewedEpisodeReference.new
    assert_difference('CatalogueEpisodeLink.count', 1) { service.call(@episode, @candidate) }
    assert_no_difference('CatalogueEpisodeLink.count') { service.call(@episode, @candidate) }
    link = CatalogueEpisodeLink.find_by!(record_id: @episode.id)
    assert_equal [12, 11, 14, 2], [link.local_season_number, link.local_episode_number,
                                  link.external_season_number, link.external_episode_number]
    assert_equal true, link.evidence['explicit_episode_mapping']
    assert_equal 11, @episode.reload.rank
    assert_equal 12, @episode.parent.rank
    assert_equal true, @episode.is_seen
  end

  test 'does not overwrite an existing different correspondence' do
    service = EncoderProjects::ReviewedEpisodeReference.new
    service.call(@episode, @candidate)
    @candidate['tmdb_episode_reference']['episode_id'] = 988
    assert_raises(ArgumentError) { service.call(@episode, @candidate) }
    assert_equal 987, CatalogueEpisodeLink.find_by!(record_id: @episode.id).external_episode_id
  end
  test 'refuses mixing different external series identities under one local root' do
    service = EncoderProjects::ReviewedEpisodeReference.new
    service.call(@episode, @candidate)
    other = @episode.parent.children.create!(french_title: 'Autre épisode', record_kind: 'episode', rank: 12,
                                              language_version: @episode.language_version)
    @candidate['tmdb_episode_reference'].merge!('series_id' => 42, 'episode_id' => 988)
    assert_raises(ArgumentError) { service.call(other, @candidate) }
    assert_nil CatalogueEpisodeLink.find_by(record_id: other.id)
  end

end
