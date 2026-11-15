require 'test_helper'

class RecordGenreSymbolsHelperTest < ActionView::TestCase
  include RecordGenreIconsHelper

  test 'the requested genres have accessible decorative symbols in a common frame' do
    expected = {
      'Fantasy' => 'magic', 'Histoire' => 'history', 'Espionnage' => 'spy',
      'Péplum' => 'roman', 'Policier' => 'police', 'Théâtre' => 'theatre',
      'Super-héros' => 'superhero', 'Thriller' => 'thriller', 'Biopic' => 'biopic'
    }
    expected.each do |name, symbol|
      assert record_genre_symbol_known?(name)
      svg = Nokogiri::HTML.fragment(record_genre_symbol(name)).at_css('svg')
      assert svg, name
      assert_equal symbol, svg['data-genre-symbol']
      assert_equal '0 0 32 32', svg['viewBox'] || svg['viewbox']
      assert_equal 'true', svg['aria-hidden']
    end
  end

  test 'accents and alternate genre names retain the intended drawing' do
    %w[Historique Biographie Fantastique Fantaisie].each do |name|
      assert record_genre_symbol_known?(name)
      assert_includes record_genre_symbol(name), 'data-genre-symbol='
    end
  end

  test 'an unmapped genre retains its name and is not an empty icon' do
    assert_not record_genre_symbol_known?('Genre sans symbole')
    fragment = Nokogiri::HTML.fragment(record_genre_symbol('Genre sans symbole'))
    assert_equal 'Genre sans symbole', fragment.text
    assert_nil fragment.at_css('svg')
  end
end
