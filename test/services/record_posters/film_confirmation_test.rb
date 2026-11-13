require 'test_helper'
require 'base64'

class RecordPosters::FilmConfirmationTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @record = Record.create!(french_title: 'Thor: Love and Thunder', year: 2022,
                             record_kind: 'standalone_video', language_version: language)
    @png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2k0AAAAASUVORK5CYII=')
    @movie = { 'id' => 616037, 'title' => 'Thor : Love and Thunder', 'original_title' => 'Thor: Love and Thunder',
               'release_date' => '2022-07-06', 'overview' => 'Présentation différente du synopsis local.',
               'poster_path' => '/ThorPoster.jpg' }
    @downloads = []
    @client = Object.new
    movie = @movie
    @client.define_singleton_method(:movie) { |id:| raise('Unexpected ID') unless id == 616037; movie }
    @download = lambda { |path| @downloads << path; @png }
    @service = RecordPosters::FilmConfirmation.new(client: @client, download: @download)
    @url = 'https://www.themoviedb.org/movie/616037-thor-love-and-thunder?language=fr-FR'
  end

  test 'preview never stores a poster or changes the record' do
    before = @record.attributes
    assert_no_difference('RecordPoster.count') do
      preview = @service.preview(@record, url: @url)
      assert_equal 616037, preview['tmdb_movie_id']
      assert preview['token'].present?
    end
    assert_empty @downloads
    assert_equal before, @record.reload.attributes
  end

  test 'explicit confirmation attaches only artwork and retains its movie reference' do
    before = @record.attributes
    token = @service.preview(@record, url: @url).fetch('token')
    assert_equal :attached, @service.confirm(@record, token: token)
    assert_equal before, @record.reload.attributes
    assert_equal @png, @record.record_poster.image.download.b
    assert_equal 616037, @record.record_poster.source['tmdb_movie_id']
    assert_equal [616037], RecordPosters::Evidence.ids(@record, 'movie')
    assert_equal 'user_confirmed_preview', @record.record_poster.source.dig('identity_confirmation', 'origin')
  end

  test 'invalid links are rejected before any download' do
    ['http://www.themoviedb.org/movie/616037', 'https://evil.test/movie/616037',
     'https://www.themoviedb.org/tv/616037', 'https://www.themoviedb.org@evil.test/movie/616037',
     'https://www.themoviedb.org/movie/0', "https://www.themoviedb.org/movie/616037\n"].each do |url|
      assert_raises(RecordPosters::FilmConfirmation::Error) { @service.preview(@record, url: url) }
    end
    assert_empty @downloads
  end

  test 'a token is scoped to one record and expires' do
    token = @service.preview(@record, url: @url).fetch('token')
    other = Record.create!(french_title: 'Autre film', record_kind: 'standalone_video', language_version: @record.language_version)
    assert_raises(RecordPosters::FilmConfirmation::Error) { @service.confirm(other, token: token) }
    travel 16.minutes do
      assert_raises(RecordPosters::FilmConfirmation::Error) { @service.confirm(@record, token: token) }
    end
    assert_empty @downloads
  end

  test 'tampered tokens cannot select an arbitrary reference or image' do
    token = @service.preview(@record, url: @url).fetch('token')
    assert_raises(RecordPosters::FilmConfirmation::Error) { @service.confirm(@record, token: "#{token}x") }
    assert_empty @downloads
    assert_not RecordPoster.exists?(record_id: @record.id)
  end

  test 'a modified record or a newly added image invalidates the preview' do
    token = @service.preview(@record, url: @url).fetch('token')
    @record.update!(abstract: 'Le synopsis a été modifié après la prévisualisation.')
    assert_raises(RecordPosters::FilmConfirmation::Error) { @service.confirm(@record, token: token) }
    token = @service.preview(@record, url: @url).fetch('token')
    RecordPosters::Store.call(@record, bytes: @png, source: { 'kind' => 'manual' })
    assert_raises(RecordPosters::FilmConfirmation::Error) { @service.confirm(@record.reload, token: token) }
    assert_empty @downloads
    assert_equal 'manual', @record.reload.record_poster.source['kind']
  end

  test 'an edit during image downloading is detected again under the lock' do
    token = @service.preview(@record, url: @url).fetch('token')
    service = RecordPosters::FilmConfirmation.new(client: @client, download: lambda { |_path|
      Record.find(@record.id).update!(abstract: 'Modification concurrente à préserver.')
      @png
    })
    assert_raises(RecordPosters::FilmConfirmation::Error) { service.confirm(@record, token: token) }
    assert_not RecordPoster.exists?(record_id: @record.id)
    assert_equal 'Modification concurrente à préserver.', @record.reload.abstract
  end

  test 'a manual image already present is never overwritten' do
    RecordPosters::Store.call(@record, bytes: @png, source: { 'kind' => 'manual' })
    token = @service.preview(@record.reload, url: @url).fetch('token')
    assert_equal :preserved, @service.confirm(@record, token: token)
    assert_equal 'manual', @record.reload.record_poster.source['kind']
  end

  test 'non film records and invalid remote image paths cannot be previewed' do
    @movie['poster_path'] = 'https://evil.test/image.jpg'
    assert_raises(RecordPosters::FilmConfirmation::Error) { @service.preview(@record, url: @url) }
    @record.update!(record_kind: 'series')
    assert_raises(RecordPosters::FilmConfirmation::Error) { @service.preview(@record, url: @url) }
  end

  test 'the same confirmation cannot attach twice' do
    token = @service.preview(@record, url: @url).fetch('token')
    @service.confirm(@record, token: token)
    assert_raises(RecordPosters::FilmConfirmation::Error) { @service.confirm(@record.reload, token: token) }
    assert_equal 1, @downloads.size
  end
end
