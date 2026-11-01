require 'test_helper'

class EncoderProjects::ProposalArtworkTest < ActiveSupport::TestCase
  test 'TMDB poster filenames use only the fixed HTTPS image host' do
    assert_equal 'https://image.tmdb.org/t/p/w185/poster-123.jpg',
                 EncoderProjects::ProposalArtwork.url('poster_path' => '/poster-123.jpg')
  end

  test 'missing or unsafe paths leave the card without an image' do
    [nil, '', '/../../private.jpg', '//other.example/poster.jpg', 'https://other.example/a.jpg',
     '/image.svg', '/image.jpg?tracking=1', '/x.jpg" onerror="bad', '/' + ('a' * 201) + '.jpg'].each do |path|
      assert_nil EncoderProjects::ProposalArtwork.url('poster_path' => path)
    end
  end
end
