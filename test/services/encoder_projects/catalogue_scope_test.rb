require 'test_helper'

class EncoderProjects::CatalogueScopeTest < ActiveSupport::TestCase
  setup do
    @user = Struct.new(:id).new(12)
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/film.json',
                 'output_path' => '/videos/film.mkv', 'source_paths' => ['/commun/to_be_cut/film.m2t'] }
  end

  test 'the proposal carries the original project and documented candidate' do
    candidate = { 'french_title' => 'Film', 'source' => { 'provider' => 'wikipedia' } }
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project, candidate: candidate)
    scope = EncoderProjects::CatalogueScope.read(token, user: @user)
    assert_equal @project, scope['project']
    assert_equal candidate, scope['candidate']
  end

  test 'a proposal cannot be used by another account or after expiration' do
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    assert_raises(ArgumentError) do
      EncoderProjects::CatalogueScope.read(token, user: Struct.new(:id).new(13))
    end
    travel 3.hours do
      assert_raises(ArgumentError) { EncoderProjects::CatalogueScope.read(token, user: @user) }
    end
  end

  test 'tampering with a documented proposal is refused' do
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    assert_raises(ArgumentError) { EncoderProjects::CatalogueScope.read("#{token}invalid", user: @user) }
  end
end
