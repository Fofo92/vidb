require 'test_helper'

class EncoderProjects::SynopsisPreferenceTest < ActiveSupport::TestCase
  def episode(provider, text, **changes)
    { 'title' => 'Le départ', 'year' => 2025, 'series_id' => 1, 'season' => 2, 'episode' => 1,
      'abstract' => text, 'source' => { 'provider' => provider, 'url' => "https://#{provider}.test/episode" } }
      .merge(changes.transform_keys(&:to_s))
  end

  def policy(*proposals)
    EncoderProjects::SynopsisPreference.call(proposals)
  end

  test 'prefers a matching TMDB synopsis without changing Wikipedia identity or mutating input' do
    wiki = episode('wikipedia', 'Une longue scène. ' * 100)
    tmdb = episode('tmdb', 'Une famille se retrouve.')
    result = policy(wiki, tmdb).first
    assert_equal 'Une famille se retrouve.', result['abstract']
    assert_equal 'wikipedia', result.dig('source', 'provider')
    assert_equal 'tmdb', result.dig('abstract_source', 'provider')
    assert_equal 'Le départ', result['title']
    assert_equal 2025, result['year']
    assert_equal 'Une longue scène. ' * 100, wiki['abstract']
  end

  test 'a detailed Wikipedia narrative is signalled instead of cut mid sentence' do
    result = policy(episode('wikipedia', 'Une longue scène. ' * 100)).sole
    assert_equal '', result['abstract']
    assert_match(/récit détaillé/, result['abstract_notice'])
  end

  test 'a complete concise Wikipedia synopsis remains available as fallback' do
    result = policy(episode('wikipedia', 'Une famille se retrouve.')).sole
    assert_equal 'Une famille se retrouve.', result['abstract']
  end

  test 'conflicting titles years or episode placements are never mixed' do
    wiki = episode('wikipedia', 'Court résumé Wikipédia.')
    [{ title: 'Autre épisode' }, { year: 2024 }, { episode: 2 }, { series_id: 2 }].each do |change|
      result = policy(wiki, episode('tmdb', 'Synopsis incompatible.', **change)).first
      assert_equal 'Court résumé Wikipédia.', result['abstract']
    end
  end

  test 'ambiguous differing TMDB synopses remain separate choices' do
    wiki = episode('wikipedia', 'Une longue scène. ' * 100)
    result = policy(wiki, episode('tmdb', 'Version A.'), episode('tmdb', 'Version B.'))
    assert_equal '', result.first['abstract']
    assert_equal ['Version A.', 'Version B.'], result.drop(1).map { |item| item['abstract'] }
  end

  test 'films require a matching title and known year before sharing a synopsis' do
    wiki = { 'french_title' => 'Film test', 'year' => 2025, 'abstract' => 'Résumé Wikipédia.',
             'source' => { 'provider' => 'wikipedia' } }
    tmdb = wiki.merge('abstract' => 'Synopsis court.', 'source' => { 'provider' => 'tmdb' })
    assert_equal 'Synopsis court.', policy(wiki, tmdb).first['abstract']
    assert_equal 'Résumé Wikipédia.', policy(wiki.except('year'), tmdb).first['abstract']
  end

  test 'the source priority is independent from proposal order' do
    result = policy(episode('wikipedia', 'Résumé.'), episode('senscritique', 'Synopsis SC.'),
                    episode('tmdb', 'Synopsis TMDB.')).first
    assert_equal 'Synopsis TMDB.', result['abstract']
  end
  test 'empty transliterations never create a false title match' do
    wiki = { 'french_title' => 'Film A', 'original_title' => 'ア', 'year' => 2025, 'abstract' => 'Résumé Wikipédia.',
             'source' => { 'provider' => 'wikipedia' } }
    other = { 'french_title' => 'Film B', 'original_title' => 'イ', 'year' => 2025, 'abstract' => 'Autre synopsis.',
              'source' => { 'provider' => 'tmdb' } }
    assert_equal 'Résumé Wikipédia.', policy(wiki, other).first['abstract']
  end

end
