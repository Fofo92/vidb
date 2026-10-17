# frozen_string_literal: true
require 'test_helper'
class FilmSearchSnapshotTest < ActiveSupport::TestCase
  test 'reads all bounded pages and searches both titles without duplicating movie ids' do
    calls=[]
    client=Object.new
    client.define_singleton_method(:search) do |title:,page:|
      calls << [title,page]
      {'page'=>page,'total_pages'=>2,'results'=>[{'id'=>page}]}
    end
    result=CatalogEnrichment::FilmSearchSnapshot.new(client:client).call(local:{'french_title'=>'Titre français','original_title'=>'Original'})
    assert_equal [1,2],result[:results].map { |film|film['id'] }
    assert_equal 4,calls.size
    assert result[:complete]
  end
  test 'an overlarge search is explicitly incomplete rather than uniquely selected' do
    client=Object.new
    client.define_singleton_method(:search) { |title:,page:|{'page'=>page,'total_pages'=>25,'results'=>[{'id'=>page}]} }
    result=CatalogEnrichment::FilmSearchSnapshot.new(client:client).call(local:{'french_title'=>'Titre','original_title'=>''})
    assert_not result[:complete]
    assert_equal 20,result[:queries].first[:pages_read]
  end
  test 'a growing result set cannot silently be reported complete' do
    client=Object.new
    client.define_singleton_method(:search) { |title:,page:|{'page'=>page,'total_pages'=>page==1 ? 2 : 3,'results'=>[]} }
    result=CatalogEnrichment::FilmSearchSnapshot.new(client:client).call(local:{'french_title'=>'Titre','original_title'=>'Titre'})
    assert_not result[:complete]
    assert_equal 1,result[:queries].size
  end
end
