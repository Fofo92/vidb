require 'test_helper'
require 'minitest/mock'

class EncoderProjects::SenscritiqueCatalogueTest < ActiveSupport::TestCase
  URL = 'https://www.senscritique.com/film/impossible/139932052'.freeze

  test 'direct link produces a signed-proposal-compatible film without searching other titles' do
    transport = lambda do |uri|
      assert_equal '/film/impossible/139932052', uri.path
      response(movie_page)
    end
    client = EncoderProjects::SenscritiqueClient.new(transport: transport)
    film = EncoderProjects::SenscritiqueCatalogue.new(client: client).call(URL).sole
    assert_equal ['Impossible', 2026, 'Drame', 'France', 'standalone_video'],
                 film.values_at('french_title', 'year', 'genres_text', 'countries_text', 'record_kind')
    assert_equal 'senscritique', film.dig('source', 'provider')
    assert_equal URL, film.dig('source', 'url')
  end

  test 'title search only follows unique film links from the SensCritique host' do
    seen = []
    transport = lambda do |uri|
      seen << uri
      if uri.path == '/search'
        assert_equal [['query', 'Impossible & ailleurs']], URI.decode_www_form(uri.query)
        response("<a href='#{URL}'>Film</a><a href='#{URL}'>Film</a>" \
                 "<a href='https://evil.test/film/x/1'>Piège</a><a href='/serie/x/1'>Série</a>")
      else
        response(movie_page)
      end
    end
    client = EncoderProjects::SenscritiqueClient.new(transport: transport)
    assert_equal 1, EncoderProjects::SenscritiqueCatalogue.new(client: client).call('Impossible & ailleurs').size
    assert_equal 2, seen.size
  end

  test 'redirects errors and unsupported pages produce explicit warnings without proposals' do
    ['302', '403', '500'].each do |status|
      client = EncoderProjects::SenscritiqueClient.new(transport: ->(_uri) { response('', status) })
      catalogue = EncoderProjects::SenscritiqueCatalogue.new(client: client)
      assert_empty catalogue.call(URL)
      assert_match status, catalogue.warnings.sole
    end
    client = EncoderProjects::SenscritiqueClient.new(transport: ->(_uri) { response('<h1>Connexion</h1>') })
    catalogue = EncoderProjects::SenscritiqueCatalogue.new(client: client)
    assert_empty catalogue.call(URL)
    assert_match 'non exploitable', catalogue.warnings.sole
  end

  test 'foreign URLs credentials nonstandard ports and series pages are never fetched' do
    client = EncoderProjects::SenscritiqueClient.new(transport: ->(_uri) { flunk 'Requête indue' })
    ['http://www.senscritique.com/film/a/1', 'https://www.senscritique.com.evil.test/film/a/1',
     'https://user@www.senscritique.com/film/a/1', 'https://www.senscritique.com:444/film/a/1',
     'https://www.senscritique.com/serie/a/1'].each { |url| assert_nil client.film_url(url) }
    assert_equal URL, client.film_url("#{URL}?tracking=1#details")
    assert_empty EncoderProjects::SenscritiqueCatalogue.new(client: client).call('https://evil.test/')
  end

  test 'oversized pages are rejected' do
    client = EncoderProjects::SenscritiqueClient.new(
      transport: ->(_uri) { response('x' * (EncoderProjects::SenscritiqueClient::LIMIT + 1)) }
    )
    assert_raises(EncoderProjects::SenscritiqueClient::Error) { client.page(URL) }
  end

  private

  def response(body, code = '200')
    Struct.new(:body, :code).new(body, code)
  end

  def movie_page
    data = { '@context' => 'https://schema.org', '@graph' => [
      { '@type' => 'Movie', 'name' => 'Impossible', 'datePublished' => '2026-10-16',
        'genre' => ['Drame'], 'countryOfOrigin' => { '@type' => 'Country', 'name' => 'France' },
        'description' => 'Un synopsis de test.' }
    ] }
    "<script type='application/ld+json'>#{JSON.generate(data)}</script>"
  end
end
