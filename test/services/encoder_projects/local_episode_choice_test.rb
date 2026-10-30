require 'test_helper'

class EncoderProjects::LocalEpisodeChoiceTest < ActiveSupport::TestCase
  Row = Struct.new(:id, :record_kind, :rank, :parent) do
    def record_kind_series?
      record_kind == 'series'
    end

    def record_kind_season?
      record_kind == 'season'
    end
  end

  setup do
    @series = Row.new(12, 'series', nil, nil)
    @project = { 'project_id' => 'stable-id', 'project_path' => '/videos/montage.json',
                 'output_path' => '/videos/montage.mkv',
                 'source_paths' => ['/commun/to_be_cut/9-1-1 - S06 E15 - Taxes mortelles.m2t'] }
  end

  test 'series choice preserves the montage and detects episode numbers without mutating the input' do
    before = Marshal.load(Marshal.dump(@project))
    result = EncoderProjects::LocalEpisodeChoice.call(@series, @project)
    assert_same @series, result[:series]
    assert_equal [6, 15], result.values_at(:season, :episode)
    assert_equal({ 'season' => 6, 'episode' => 15 }, result[:project]['episode_target'])
    assert_equal @project, result[:project].except('episode_target')
    assert_equal before, @project
  end

  test 'a selected season takes precedence including season zero' do
    season = Row.new(13, 'season', 0, @series)
    result = EncoderProjects::LocalEpisodeChoice.call(season, @project)
    assert_same @series, result[:series]
    assert_equal [0, 15], result.values_at(:season, :episode)
  end

  test 'an explicit numbering choice is kept over the source filename' do
    project = @project.merge('episode_target' => { 'season' => 14, 'episode' => 2 })
    result = EncoderProjects::LocalEpisodeChoice.call(@series, project)
    assert_equal [14, 2], result.values_at(:season, :episode)
  end

  test 'unnumbered captures offer editable defaults without inventing an episode title' do
    project = @project.merge('source_paths' => ['/commun/to_be_cut/Documentaire.m2t'])
    result = EncoderProjects::LocalEpisodeChoice.call(@series, project)
    assert_equal [1, 1], result.values_at(:season, :episode)
    request = EncoderProjects::EpisodeRequest.new(result[:project])
    assert_equal '', request.title
  end

  test 'films individual episodes and seasons without a series cannot become a series choice' do
    [Row.new(13, 'standalone_video'), Row.new(14, 'episode'), Row.new(15, 'undetermined'),
     Row.new(16, 'season', 2, nil)].each do |record|
      assert_nil EncoderProjects::LocalEpisodeChoice.call(record, @project)
    end
  end
end
