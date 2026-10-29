require 'test_helper'

class Tv::AcquiredEpisodeIdentityTest < ActiveSupport::TestCase
  Programme = Struct.new(:titles, :episode_numbers, :subtitles)

  def programme(title = 'Joséphine, ange gardien', number = '11.10.')
    Programme.new([{ 'value' => title, 'language' => 'fr' }], [{ 'system' => 'xmltv_ns', 'value' => number }], [])
  end

  test 'converts XMLTV zero based coordinates and normalizes accents and punctuation' do
    expected = ['josephine-ange-gardien', 12, 11]
    assert_equal expected, Tv::AcquiredEpisodeIdentity.key(programme)
    assert_equal expected, Tv::AcquiredEpisodeIdentity.key(programme('JOSEPHINE, ange gardien - Saison 12'))
  end

  test 'does not invent numbers or accept a conflicting season suffix' do
    assert_nil Tv::AcquiredEpisodeIdentity.key(programme('Joséphine', ''))
    assert_nil Tv::AcquiredEpisodeIdentity.key(programme('Joséphine - Saison 14'))
  end

  test 'a contradictory episode title prevents a match' do
    item = programme
    item.subtitles = [{ 'value' => 'Chasse aux fantômes', 'language' => 'fr' }]
    assert Tv::AcquiredEpisodeIdentity.concordant?(item, ['chasse-aux-fantomes'])
    refute Tv::AcquiredEpisodeIdentity.concordant?(item, ['autre-episode'])
  end
end
