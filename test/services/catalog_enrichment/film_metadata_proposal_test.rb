# frozen_string_literal: true
require 'test_helper'
class FilmMetadataProposalTest < ActiveSupport::TestCase
  setup do
    @local={'record_id'=>1,'year'=>2021,'year_basis'=>'unknown','year_evidence'=>{},'genres'=>[],'abstract'=>'Texte corrigé manuellement.'}
    @movie={'id'=>42,'release_date'=>'2022-01-12','genres'=>[{'id'=>35,'name'=>'Comédie'},{'id'=>18,'name'=>'Drame'}]}
    @proposer=CatalogEnrichment::FilmMetadataProposal.new
  end
  def proposal
    @proposer.call(local:@local,movie:@movie,known_genres:['Comédie','Drame','Action','Aventure','Thriller'])
  end
  test 'missing genres and unknown year receive separate sourced proposals without mutating inputs' do
    original=@local.deep_dup
    result=proposal
    assert_equal 'candidate',result[:year][:status]
    assert_equal 2022,result[:year][:proposed]
    assert_equal ['Comédie','Drame'],result[:genres][:proposed]
    assert_equal 'candidate',result[:genres][:status]
    assert_equal original,@local
    assert_equal false,result[:execution_authorized]
    assert_equal 'preserved',result[:abstract][:status]
  end
  test 'existing genre corrections are preserved even when the source differs' do
    @local['genres']=['Espionnage']
    assert_equal 'protected',proposal[:genres][:status]
    assert_equal ['Espionnage'],@local['genres']
  end
  test 'three external genres are never truncated to two' do
    @movie['genres']=[{'id'=>28},{'id'=>12},{'id'=>53}]
    assert_equal 'needs_review',proposal[:genres][:status]
    assert_nil proposal[:genres][:proposed]
  end
  test 'a qualified year or existing evidence is protected' do
    @local['year_basis']='first_release'
    assert_equal 'protected',proposal[:year][:status]
    @local['year_basis']='unknown';@local['year_evidence']={'manual'=>true}
    assert_equal 'protected',proposal[:year][:status]
  end
  test 'documentary genre or absent local reference requires classification review' do
    @movie['genres']=[{'id'=>99,'name'=>'Documentaire'}]
    assert_equal 'needs_review',proposal[:genres][:status]
    @movie['genres']=[{'id'=>27,'name'=>'Horreur'}]
    assert_equal 'needs_review',proposal[:genres][:status]
  end
  test 'invalid or absent dates do not silently confirm an old year' do
    @movie['release_date']='2022-02-31'
    assert_equal 'needs_review',proposal[:year][:status]
    @movie['release_date']=''
    assert_equal 'needs_review',proposal[:year][:status]
  end
  test 'a remote first release far from the local year remains a review case' do
    @movie['release_date']='1950-01-01'
    assert_equal 'needs_review',proposal[:year][:status]
  end

end
