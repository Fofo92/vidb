require 'test_helper'

class EncoderProjects::TmdbEpisodeProposalTest < ActiveSupport::TestCase
  Numbers = Struct.new(:season, :episode)
  Scope = Struct.new(:ids) { def select(*) = ids }
  Series = Struct.new(:id, :subtree)
  Links = Struct.new(:rows) { def where(**) = rows }
  Link = Struct.new(:local_season_number, :local_episode_number, :record, :evidence)

  def page
    { 'title' => 'Série test', 'text' => { '*' => '<h3>Saison 10 (2024)</h3>' \
      '<ol><li>Madeleine</li><li>Nikki et Evelina</li><li>Birgitta</li></ol>' } }
  end

  def client
    rows = ['Madeleine', 'Madeleine (2)', 'Nikki & Evelina', 'Nikki & Evelina (2)', 'Birgitta', 'Birgitta (2)']
           .each_with_index.map do |name, index|
      { 'id' => 100 + index, 'episode_number' => index + 1, 'name' => name,
        'air_date' => '2024-08-14', 'runtime' => 44, 'overview' => name }
    end
    Object.new.tap do |remote|
      remote.define_singleton_method(:get) do |path, **_options|
        path == 'tv/987' ? { 'original_language' => 'sv' } : { 'episodes' => rows }
      end
    end
  end

  def service(wiki: page, links: [])
    EncoderProjects::TmdbEpisodeProposal.new(client: client, wikipedia_page: wiki, links: Links.new(links), warnings: [])
  end

  test 'uses local episode two for external parts three and four without a series specific rule' do
    result = service.call(987, Series.new(12, Scope.new([])), Numbers.new(10, 2))
    assert_equal 'Nikki et Evelina', result['title']
    assert_equal [102, 103], result['external_parts'].pluck('episode_id')
    assert_equal 102, result.dig('source', 'episode_id')
    assert_match %r{/season/10/episode/3\z}, result.dig('source', 'url')
    assert_equal [[1, 2], [3, 4], [5, 6]], result['edition_mapping'].pluck('external_numbers')
    assert_equal 'Série test', result.dig('numbering_source', 'page_title')
  end

  test 'reuses a stored convention when Wikipedia is unavailable and preserves a manual title' do
    link = Link.new(10, 2, Struct.new(:french_title).new('Mon titre corrigé'),
                    { 'external_parts' => [{ 'episode_id' => 102 }, { 'episode_id' => 103 }],
                      'numbering_source' => { 'page_title' => 'Série test' } })
    result = service(wiki: nil, links: [link]).call(987, Series.new(12, Scope.new([])), Numbers.new(10, 2))
    assert_equal 'Mon titre corrigé', result['title']
    assert_equal [102, 103], result['external_parts'].pluck('episode_id')
    assert_raises(ArgumentError) do
      service(wiki: nil, links: [link]).call(987, Series.new(12, Scope.new([])), Numbers.new(10, 3))
    end
  end
end
