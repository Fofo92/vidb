require 'test_helper'

class EncoderProjects::CatalogueCompletionProposalTest < ActiveSupport::TestCase
  def proposal(provider, title: 'Départ', id: nil)
    row = { 'series_id' => 12, 'season' => 6, 'episode' => 24, 'title' => title, 'year' => 2011,
            'source' => { 'provider' => provider } }
    row['catalogue_completion'] = { 'record_id' => 12, 'tmdb_id' => id } if id
    row
  end

  test 'shares a single concordant identity with Wikipedia without changing its editorial fields' do
    wiki = proposal('wikipedia')
    tmdb = proposal('tmdb', id: 4057)
    result = EncoderProjects::CatalogueCompletionProposal.call([wiki, tmdb])
    assert_equal tmdb['catalogue_completion'], result.first['catalogue_completion']
    assert_equal 'wikipedia', result.first.dig('source', 'provider')
    assert_nil wiki['catalogue_completion']
  end

  test 'does not transfer an identity across a numbering title or year disagreement' do
    wiki = proposal('wikipedia')
    mismatches = [proposal('tmdb', title: 'Autre', id: 1),
                  proposal('tmdb', id: 2).merge('episode' => 22),
                  proposal('tmdb', id: 3).merge('year' => 2010)]
    result = EncoderProjects::CatalogueCompletionProposal.call([wiki, *mismatches])
    assert_nil result.first['catalogue_completion']
  end

  test 'ambiguous external identities require choosing a source instead of completing through Wikipedia' do
    result = EncoderProjects::CatalogueCompletionProposal.call(
      [proposal('wikipedia'), proposal('tmdb', id: 1), proposal('tmdb', id: 2)]
    )
    assert_nil result.first['catalogue_completion']
    assert_equal 1, result[1].dig('catalogue_completion', 'tmdb_id')
  end
end
