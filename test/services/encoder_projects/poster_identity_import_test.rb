require 'test_helper'
require 'base64'

class EncoderProjects::PosterIdentityImportTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Film existant', original_title: 'Existing film', year: 1945,
                             record_kind: 'standalone_video', language_version: language, abstract: 'Résumé conservé')
    @candidate = { 'poster_path' => '/new.jpg', 'source' => {
      'provider' => 'tmdb', 'tmdb_movie_id' => 7, 'url' => 'https://www.themoviedb.org/movie/7'
    } }
    @png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2k0AAAAASUVORK5CYII=')
  end

  test 'a confirmed source is retained for an existing film without rewriting any record field' do
    before = @record.attributes
    assert_equal :scheduled, EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    assert_equal before, @record.reload.attributes
    assert_equal [7], RecordPosters::Evidence.ids(@record, 'movie')
    assert_equal '/new.jpg', @record.record_poster.source.dig('encoder_pending', 'poster_path')
    assert_not @record.record_poster.image.attached?
    assert_equal :preserved, EncoderProjects::PosterIdentityImport.call(@record, @candidate)
  end

  test 'a grouped Wikipedia proposal retains its confirmed additional TMDB source' do
    candidate = @candidate.merge('source' => { 'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Film' },
                                 'additional_sources' => [@candidate.fetch('source')])
    assert_equal :scheduled, EncoderProjects::PosterIdentityImport.call(@record, candidate)
    assert_equal [7], RecordPosters::Evidence.ids(@record.reload, 'movie')
  end

  test 'a synopsis credit alone does not establish a confirmed artwork identity' do
    candidate = @candidate.merge('source' => { 'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Film' },
                                 'abstract_source' => @candidate.fetch('source'))
    assert_equal :unidentified, EncoderProjects::PosterIdentityImport.call(@record, candidate)
    assert_nil @record.reload.record_poster
  end

  test 'manual artwork and deliberate removal are never reactivated by a new encoding' do
    poster = RecordPoster.create!(record: @record, source: { 'kind' => 'manual' })
    assert_equal :preserved, EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    assert_equal({ 'kind' => 'manual' }, poster.reload.source)
    RecordPosters::Store.call(@record, bytes: @png, source: { 'kind' => 'manual' })
    blob_id = @record.record_poster.image.blob.id
    assert_equal :preserved, EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    assert_equal blob_id, @record.reload.record_poster.image.blob.id
  end

  test 'contradictory persisted identities do not schedule an automatic overwrite' do
    @record.update!(year_evidence: { 'tmdb_movie_id' => 8 })
    assert_equal :conflict, EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    assert_nil @record.reload.record_poster
  end

  test 'an automatic image is refreshed using the confirmed poster without an extra identity search' do
    RecordPosters::Store.call(@record, bytes: @png, source: {
      'kind' => 'tmdb', 'url' => 'https://www.themoviedb.org/movie/7', 'poster_path' => '/old.jpg'
    })
    before = @record.attributes
    assert_equal :scheduled, EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    client = Object.new
    client.define_singleton_method(:poster) { |_target| raise 'Unexpected catalogue request' }
    paths = []
    png = @png
    download = ->(path) { paths << path; png }
    assert_equal :attached, RecordPosters::Fetch.new(client: client, download: download).call(@record)
    assert_equal ['/new.jpg'], paths
    assert_equal '/new.jpg', @record.reload.record_poster.source['poster_path']
    assert_not @record.record_poster.source.key?('encoder_pending')
    assert_equal before, @record.attributes
    assert_equal :preserved, EncoderProjects::PosterIdentityImport.call(@record, @candidate)
  end

  test 'a manual upload during download wins over the automatic refresh' do
    RecordPosters::Store.call(@record, bytes: @png, source: {
      'kind' => 'tmdb', 'url' => 'https://www.themoviedb.org/movie/7', 'poster_path' => '/old.jpg'
    })
    EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    download = lambda do |_path|
      RecordPosters::Store.call(@record, bytes: @png, source: { 'kind' => 'manual' })
      @png
    end
    assert_equal :preserved, RecordPosters::Fetch.new(client: Object.new, download: download).call(@record)
    assert_equal 'manual', @record.reload.record_poster.source['kind']
  end

  test 'a download failure preserves the old image and its pending retry' do
    RecordPosters::Store.call(@record, bytes: @png, source: {
      'kind' => 'tmdb', 'url' => 'https://www.themoviedb.org/movie/7', 'poster_path' => '/old.jpg'
    })
    EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    blob = @record.record_poster.image.blob.id
    download = ->(_path) { raise RecordPosters::ImageDownload::Error, 'Offline' }
    assert_raises(RecordPosters::ImageDownload::Error) do
      RecordPosters::Fetch.new(client: Object.new, download: download).call(@record)
    end
    assert_equal blob, @record.reload.record_poster.image.blob.id
    assert @record.record_poster.source['encoder_pending']
  end

  test 'an older download cannot consume a newer pending request for a missing image' do
    EncoderProjects::PosterIdentityImport.call(@record, @candidate)
    download = lambda do |_path|
      poster = @record.record_poster
      source = poster.source.deep_dup
      source['encoder_pending']['poster_path'] = '/newer.jpg'
      poster.update!(source: source)
      @png
    end
    assert_equal :preserved, RecordPosters::Fetch.new(client: Object.new, download: download).call(@record)
    assert_not @record.reload.record_poster.image.attached?
    assert_equal '/newer.jpg', @record.record_poster.source.dig('encoder_pending', 'poster_path')
  end

  test 'episode artwork is scheduled on the series rather than on the episode' do
    series = Record.create!(french_title: 'Série', record_kind: 'series', language_version: @record.language_version)
    season = series.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season',
                                     language_version: @record.language_version)
    episode = season.children.create!(french_title: 'Épisode', rank: 1, record_kind: 'episode',
                                      language_version: @record.language_version)
    candidate = { 'poster_path' => '/series.jpg', 'source' => { 'url' => 'https://www.themoviedb.org/tv/9' } }
    assert_equal :scheduled, EncoderProjects::PosterIdentityImport.call(episode, candidate)
    assert_equal [9], RecordPosters::Evidence.ids(series.reload, 'tv')
    assert_nil episode.reload.record_poster
  end

  test 'a failed enclosing confirmation rolls back the pending artwork reference' do
    assert_no_difference 'RecordPoster.count' do
      Record.transaction do
        EncoderProjects::PosterIdentityImport.call(@record, @candidate)
        raise ActiveRecord::Rollback
      end
    end
    assert_nil @record.reload.record_poster
  end
end
