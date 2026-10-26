require 'test_helper'

class EncoderProjects::EpisodeSeasonDefaultsTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |row| row.long_name = 'Indéterminée' }
    @series = Record.create!(french_title: 'Série test', record_kind: 'series', language_version: language)
    @season = @series.children.create!(french_title: 'Saison 07', rank: 7, record_kind: 'season',
                                       language_version: language)
    @drama = Gender.find_or_create_by!(name: 'Drame')
    @thriller = Gender.find_or_create_by!(name: 'Thriller')
    @series.with_reviewed_genre_assignment { @series.genders = [@drama] }
    @season.with_reviewed_genre_assignment { @season.genders = [@thriller] }
    @numbers = Struct.new(:season, :episode, :title).new(7, 2, 'Titre')
    @candidate = { 'gender_ids' => [@drama.id], 'country_ids' => [] }
  end

  test 'a missing episode proposes the genre of its season before external or series genres' do
    result = EncoderProjects::EpisodeDefaults.call(@series, @numbers, @candidate)
    assert_equal [@thriller.id], result['gender_ids']
    assert_nil result['existing_record_id']
  end

  test 'an existing episode keeps its own explicit genre' do
    episode = @season.children.create!(french_title: 'Titre', rank: 2, record_kind: 'episode',
                                       language_version: @series.language_version)
    episode.with_reviewed_genre_assignment { episode.genders = [@drama] }
    result = EncoderProjects::EpisodeDefaults.call(@series, @numbers, @candidate)
    assert_equal [@drama.id], result['gender_ids']
    assert_equal episode.id, result['existing_record_id']
  end

  test 'without a season the series genre is proposed' do
    @numbers.season = 8
    result = EncoderProjects::EpisodeDefaults.call(@series, @numbers, @candidate)
    assert_equal [@drama.id], result['gender_ids']
  end

  test 'a new episode inherits the selected season genre without changing the series' do
    proposal = EncoderProjects::EpisodeDefaults.call(@series, @numbers, @candidate)
    episode = @season.children.create!(french_title: 'Titre', rank: 2, record_kind: 'episode',
                                       language_version: @series.language_version)
    EncoderProjects::EpisodeReferenceEnrichment.new(proposal, {}).call(episode)
    assert_equal [@thriller.id], episode.reload.effective_genders.map(&:id)
    assert_empty episode.genders
    assert_equal [@thriller.id], @season.reload.genders.map(&:id)
    assert_equal [@drama.id], @series.reload.genders.map(&:id)
  end
end
