require 'test_helper'
require 'minitest/mock'

class EncoderUnifiedSearchControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'unified-search@example.com', password: 'password')
    project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/Gerta.json',
                'output_path' => '/videos/Gerta.mkv', 'source_paths' => ['/commun/Gerta.m2t'] }
    @request_token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    sign_in @user
  end

  test 'series can be selected from an unnumbered capture without creating records' do
    series = { 'tmdb_id' => 335_534, 'title' => 'Gerta et le monde déchiré',
               'original_title' => 'Gerta Schnirch', 'year' => 2026 }
    search = Object.new
    search.define_singleton_method(:call) { |_query| [series] }
    films = Object.new
    films.define_singleton_method(:call) { |_query| [] }
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      EncoderProjects::SeriesCatalogueSearch.stub(:new, -> { search }) do
        EncoderProjects::FilmCatalogue.stub(:new, -> { films }) do
          get encoder_projects_catalogue_path, params: { request_token: @request_token, q: 'Gerta' }
        end
      end
    end
    assert_response :success
    assert_select 'h2', /Gerta.*2026.*Série/
    assert_select 'input[name="tmdb_series_id"][value="335534"]'
    assert_select 'input[name="season_number"]'
    assert_select 'input[name="episode_number"]'
  end
end
