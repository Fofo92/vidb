require "test_helper"

class RecordPosters::ImageDownloadTest < ActiveSupport::TestCase
  test "rejects arbitrary URLs and traversal before attempting network access" do
    ["https://example.com/a.jpg", "//example.com/a.jpg", "/../a.jpg", "/a.svg", "/a.jpg?redirect=x"].each do |path|
      assert_raises(RecordPosters::ImageDownload::Error) { RecordPosters::ImageDownload.new.call(path) }
    end
  end

  test "a redirect is rejected rather than followed" do
    response = Struct.new(:code).new("302")
    http = Object.new
    http.define_singleton_method(:request) { |_request, &block| block.call(response) }
    assert_raises(RecordPosters::ImageDownload::Error) do
      RecordPosters::ImageDownload.new.send(:read_image, http, URI("https://image.tmdb.org/t/p/w342/a.jpg"))
    end
  end

  test "stops downloading as soon as the limit is exceeded" do
    response = Object.new
    response.define_singleton_method(:code) { "200" }
    response.define_singleton_method(:read_body) { |&block| block.call("x" * (RecordPoster::MAX_BYTES + 1)) }
    http = Object.new
    http.define_singleton_method(:request) { |_request, &block| block.call(response) }
    assert_raises(RecordPosters::ImageDownload::Error) do
      RecordPosters::ImageDownload.new.send(:read_image, http, URI("https://image.tmdb.org/t/p/w342/a.jpg"))
    end
  end
end
