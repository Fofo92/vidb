# frozen_string_literal: true
require 'test_helper'
class FilmIdentityComparisonTest < ActiveSupport::TestCase
  setup do
    @local={'french_title'=>'Une étrange aventure','original_title'=>'','year'=>2022,'abstract'=>'Une jeune femme quitte son village et retrouve sa famille après plusieurs années de voyage.'}
    @film={'id'=>42,'title'=>'Une étrange aventure','original_title'=>'Another title','release_date'=>'2023-05-01','overview'=>@local['abstract']}
    @matcher=CatalogEnrichment::FilmIdentityComparison.new
  end
  test 'title synopsis and nearby year support a candidate despite a one year discrepancy' do
    result=@matcher.call(local:@local,results:[@film])
    assert_equal 'candidate',result[:status]
    assert_equal 42,result[:tmdb_id]
  end
  test 'a title and year without a matching synopsis do not establish identity' do
    @film['overview']='Un astronaute traverse une galaxie inconnue.'
    assert_equal 'needs_review',@matcher.call(local:@local,results:[@film])[:status]
  end
  test 'homonyms supported by the same evidence remain ambiguous' do
    assert_equal 'needs_review',@matcher.call(local:@local,results:[@film,@film.merge('id'=>43)])[:status]
  end
  test 'missing titles do not match missing remote fields' do
    @local['french_title']='';@film['original_title']=''
    assert_equal 'needs_review',@matcher.call(local:@local,results:[@film])[:status]
  end
  test 'a distant year or invalid release date requires review' do
    @film['release_date']='1970-01-01'
    assert_equal 'needs_review',@matcher.call(local:@local,results:[@film])[:status]
    @film['release_date']='2022-02-31'
    assert_equal 'needs_review',@matcher.call(local:@local,results:[@film])[:status]
  end
  test 'a missing local year can still be supported by title and detailed synopsis' do
    @local['year']=nil
    assert_equal 'candidate',@matcher.call(local:@local,results:[@film])[:status]
  end
end
