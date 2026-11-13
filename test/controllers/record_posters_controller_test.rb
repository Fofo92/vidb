require "test_helper"
require "base64"
require "minitest/mock"

class RecordPostersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "posters@example.com", password: "password")
    sign_in @user
    language = LanguageVersion.create!(short_name: "IND", long_name: "Indéterminée")
    @record = Record.create!(french_title: "Film sans image", record_kind: "standalone_video", language_version: language)
    @png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2k0AAAAASUVORK5CYII=")
  end

  test "show doubles artwork dimensions only when attached and never adds a blank image" do
    get record_url(@record)
    assert_response :success
    assert_select "[data-record-poster]", count: 0
    assert_select "[data-record-poster-controls]", count: 1
    RecordPosters::Store.call(@record, bytes: @png, source: { "kind" => "manual" })
    get record_url(@record)
    assert_select "[data-record-poster] img[width='240']", count: 1
    get record_poster_url(@record)
    assert_response :success
    assert_equal "image/png", response.media_type
    assert_equal @png, response.body.b
  end

  test "upload is local and preserves record states" do
    file = Tempfile.new(["poster", ".png"])
    file.binmode
    file.write(@png)
    file.rewind
    before = @record.attributes
    upload = Rack::Test::UploadedFile.new(file.path, "image/png")
    patch record_poster_url(@record), params: { poster: { image: upload } }
    assert_redirected_to record_url(@record)
    assert_equal before, @record.reload.attributes
    assert_equal "manual", @record.record_poster.source["kind"]
  ensure
    file&.close!
  end

  test "remove image disables automatic replacement while preserving states" do
    RecordPosters::Store.call(@record, bytes: @png, source: { "kind" => "manual" })
    before = @record.attributes
    delete record_poster_url(@record)
    assert_redirected_to record_url(@record)
    assert_not @record.reload.record_poster.image.attached?
    assert_equal "manual", @record.record_poster.source["kind"]
    assert_equal before, @record.attributes
  end

  test "image changes require authentication" do
    sign_out @user
    delete record_poster_url(@record)
    assert_redirected_to new_user_session_url
    assert_not RecordPoster.exists?(record: @record)
  end

  test "a preexisting series without a TMDB reference can request automatic artwork recovery" do
    @record.update!(record_kind: 'series', french_title: 'Ancienne série sans référence')
    assert_nil RecordPosters::Target.call(@record)
    get record_url(@record)
    assert_response :success
    assert_select "[data-record-poster-controls] form[action='#{fetch_record_poster_path(@record)}']", count: 1
    assert_includes response.body, 'Récupérer depuis TMDB'
  end

  test 'an unidentified film opens the comparison page instead of claiming an image is waiting' do
    fetcher = Object.new
    fetcher.define_singleton_method(:call) { |_record, restore:| :unidentified }
    RecordPosters::Fetch.stub(:new, -> { fetcher }) do
      assert_no_difference('RecordPoster.count') { post fetch_record_poster_url(@record) }
    end
    assert_redirected_to review_record_poster_url(@record)
    assert_not_includes flash[:notice], 'conservée en attente'
  end

  test 'the manual reference flow is available even when a synopsis is missing' do
    get record_url(@record)
    assert_select "a[href='#{review_record_poster_path(@record)}']", count: 1
    reviewer = Object.new
    reviewer.define_singleton_method(:call) { |_record| { message: 'Synopsis local absent.', candidates: [] } }
    RecordPosters::FilmReview.stub(:new, -> { reviewer }) { get review_record_poster_url(@record) }
    assert_response :success
    assert_select 'input[name=tmdb_url]', count: 1
    assert_select '[data-poster-film-review]', count: 1
  end

  test 'preview and explicit confirmation preserve the editorial record and viewing states' do
    movie = { 'id' => 616037, 'title' => 'Thor', 'original_title' => 'Thor',
              'release_date' => '2022-07-06', 'overview' => 'Une présentation externe.', 'poster_path' => '/poster.jpg' }
    client = Object.new
    client.define_singleton_method(:movie) { |id:| movie }
    service = RecordPosters::FilmConfirmation.new(client: client, download: ->(_path) { @png })
    before = @record.attributes
    RecordPosters::FilmConfirmation.stub(:new, service) do
      assert_no_difference('RecordPoster.count') do
        post preview_record_poster_url(@record), params: { tmdb_url: 'https://www.themoviedb.org/movie/616037' }
      end
      assert_response :success
      assert_select '[data-poster-film-preview]', count: 1
      token = css_select('input[name=confirmation_token]').first['value']
      post confirm_record_poster_url(@record), params: { confirmation_token: token }
    end
    assert_redirected_to record_url(@record)
    assert_equal before, @record.reload.attributes
    assert_equal 616037, @record.record_poster.source['tmdb_movie_id']
  end

  test 'invalid links and tokens return to the comparison page without saving an image' do
    assert_no_difference('RecordPoster.count') do
      post preview_record_poster_url(@record), params: { tmdb_url: 'https://evil.test/movie/123' }
      assert_redirected_to review_record_poster_url(@record)
      post confirm_record_poster_url(@record), params: { confirmation_token: 'tampered' }
      assert_redirected_to review_record_poster_url(@record)
    end
  end

  test 'comparison preview and confirmation require authentication' do
    sign_out @user
    get review_record_poster_url(@record)
    assert_redirected_to new_user_session_url
    post preview_record_poster_url(@record), params: { tmdb_url: 'https://www.themoviedb.org/movie/616037' }
    assert_redirected_to new_user_session_url
    post confirm_record_poster_url(@record), params: { confirmation_token: 'token' }
    assert_redirected_to new_user_session_url
  end

  test 'the movie confirmation route refuses series and retains a usable form on search failure' do
    reviewer = Object.new
    reviewer.define_singleton_method(:call) { |_record| raise CatalogEnrichment::TmdbClient::Error, 'Unavailable' }
    RecordPosters::FilmReview.stub(:new, -> { reviewer }) { get review_record_poster_url(@record) }
    assert_response :success
    assert_select 'input[name=tmdb_url]', count: 1
    @record.update!(record_kind: 'series')
    get review_record_poster_url(@record)
    assert_redirected_to record_url(@record)
  end
end
