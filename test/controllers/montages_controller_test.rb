require 'test_helper'
require 'minitest/mock'

class MontagesControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'montage-menu@example.com', password: 'password')
    @configuration = { 'url' => 'https://vidb.test', 'token' => 'a' * 64, 'user_id' => @user.id }
    host! 'vidb.test'
    https!
  end

  test 'montage requires login then offers the four actual desktop actions' do
    get montage_path
    assert_redirected_to new_user_session_path
    sign_in @user
    EncoderProjects::Settings.stub(:read, @configuration) do
      assert_no_difference ['VideoAsset.count', 'ReconciliationCase.count'] do
        get montage_path
      end
    end
    assert_response :success
    assert_select 'h1', 'Montage'
    assert_select 'a[href^="vidb-encoder:"]', count: 0
    assert_select 'button[data-action="encoder-launch#open"][target]', count: 0
    assert_select 'button[type="button"][data-encoder-launch-url-param^="vidb-encoder://desktop?"]', count: 4
    assert_select 'div[aria-label="Commandes de montage"] button', text: 'Encoder un DVD'
    assert_select 'div[aria-label="Commandes de montage"] button', text: 'Reprendre un projet'
  end

  test 'the main navigation separates catalogue scans montage television and shared tools' do
    sign_in @user
    EncoderProjects::Settings.stub(:read, @configuration) { get montage_path }
    assert_select 'nav[aria-label="Navigation principale"]' do
      assert_select 'a[href="' + records_path + '"]', text: 'Vidéothèque'
      assert_select 'a[href="' + montage_path + '"]', text: 'Montage'
      assert_select 'ul[aria-labelledby="libraryNavigation"]' do
        assert_select 'a[href="' + dvd_scan_path + '"]', text: 'Ajouter un DVD par scan'
        assert_select 'a[href="' + dvd_preparations_path + '"]', text: 'Scans DVD à identifier'
      end
      assert_select 'ul[aria-labelledby="tvNavigation"]' do
        assert_select 'a[href="' + tv_guide_path + '"]', text: 'Planning'
        assert_select 'a[href="' + tv_recording_intents_path + '"]', text: 'Enregistrements'
      end
      assert_select 'ul[aria-labelledby="toolsNavigation"]' do
        assert_select 'a[href="' + library_inventory_path + '"]', text: 'Inventaire et doublons'
        assert_select 'a[href="' + reconciliation_workbench_path + '"]', text: 'Qualification et rapprochement'
        assert_select 'a[href="' + genders_path + '"]', text: 'Genres cinématographiques'
        assert_select 'a[href="' + language_versions_path + '"]', text: 'Versions linguistiques'
        assert_select 'a[href="' + media_path + '"]', text: 'Supports'
      end
    end
    ids = css_select('nav[aria-label="Navigation principale"] [id]').map { |node| node['id'] }
    assert_equal ids.uniq, ids
  end

  test 'an unavailable bridge or another configured account shows an explanation without dead launch links' do
    sign_in @user
    EncoderProjects::Settings.stub(:read, @configuration.merge('user_id' => @user.id + 1)) do
      get montage_path
    end
    assert_response :success
    assert_select '.alert-warning', /autre compte/
    assert_select 'button[type="button"][data-encoder-launch-url-param^="vidb-encoder://desktop?"]', count: 0
    EncoderProjects::Settings.stub(:read, -> { raise ArgumentError, 'Passerelle non configurée' }) do
      get montage_path
    end
    assert_response :success
    assert_select '.alert-warning', /Passerelle non configurée/
  end

  test 'desktop actions are authenticated and never create an association or physical copy' do
    sign_in @user
    EncoderProjects::Settings.stub(:read, @configuration) do
      get montage_path
      urls = css_select('div[aria-label="Commandes de montage"] button').map { |node| node['data-encoder-launch-url-param'] }
      urls.each do |url|
        token = URI.decode_www_form(URI(url).query).to_h.fetch('ticket')
        assert_no_difference ['VideoAsset.count', 'ReconciliationCase.count'] do
          post '/encoder_projects/launch_binding', params: { desktop_token: token },
                                                   headers: { 'Authorization' => "Bearer #{@configuration['token']}" }, as: :json
        end
        assert_response :success
        assert_includes EncoderProjects::DesktopTicket::ACTIONS, response.parsed_body['desktop_action']
      end
      token = URI.decode_www_form(URI(urls.first).query).to_h.fetch('ticket')
      post '/encoder_projects/launch_binding', params: { desktop_token: token }, as: :json
      assert_response :unauthorized
      post '/encoder_projects/launch_binding', params: { desktop_token: token, project: { project_id: 'invalid' } },
                                               headers: { 'Authorization' => "Bearer #{@configuration['token']}" }, as: :json
      assert_response :unprocessable_content
    end
  end
end
