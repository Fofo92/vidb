require "test_helper"
require "base64"

class RecordPostersControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "posters@example.com", password: "password")
    sign_in @user
    language = LanguageVersion.create!(short_name: "IND", long_name: "Indéterminée")
    @record = Record.create!(french_title: "Film sans image", record_kind: "standalone_video", language_version: language)
    @png = Base64.decode64("iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2k0AAAAASUVORK5CYII=")
  end

  test "show has compact artwork only when attached and never adds a blank image" do
    get record_url(@record)
    assert_response :success
    assert_select "[data-record-poster]", count: 0
    assert_select "[data-record-poster-controls]", count: 1
    RecordPosters::Store.call(@record, bytes: @png, source: { "kind" => "manual" })
    get record_url(@record)
    assert_select "[data-record-poster] img[width='120']", count: 1
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
end
