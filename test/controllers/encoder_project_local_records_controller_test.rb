require 'test_helper'

class EncoderProjectLocalRecordsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'local-record-encoder@example.com', password: 'password')
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @title = "États-Unis : la fuite des cerveaux vers l’Europe"
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/documentaire.json',
                 'output_path' => '/videos/documentaire.mkv', 'source_paths' => ['/commun/to_be_cut/documentaire.m2t'] }
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    sign_in @user
  end

  def search(query = @title)
    get encoder_projects_local_records_path, params: { request_token: @token, q: query }
  end

  def choose(record, token: @token)
    post encoder_projects_local_records_path, params: { request_token: token, record_id: record.id, q: @title }
  end

  def create_record(kind: 'standalone_video')
    Record.create!(french_title: @title, record_kind: kind, language_version: @language)
  end

  test 'refresh finds a newly created record without creating proposals or bindings' do
    search
    assert_response :success
    assert_select 'input[name="record_id"]', count: 0
    record = create_record
    assert_no_difference ['Record.count', 'VideoAsset.count', 'ReconciliationCase.count'] do
      search
    end
    assert_response :success
    assert_select "input[name='record_id'][value='#{record.id}']"
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
  end

  test 'an explicit choice binds the existing record without rewriting it or creating a copy' do
    record = create_record
    before = record.attributes
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      choose(record)
    end
    assert_redirected_to record_path(record, encoder_prepared: 1)
    assert_equal record.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
    assert_equal before, record.reload.attributes
    assert_no_difference('Record.count') { choose(record) }
  end

  test 'qualification is checked again on submission' do
    record = create_record(kind: 'undetermined')
    search
    assert_select 'input[name="record_id"]', count: 0
    assert_select "a[href='#{edit_record_path(record)}']"
    choose(record)
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
    record.update!(record_kind: 'standalone_video')
    search
    assert_select "input[name='record_id'][value='#{record.id}']"
  end

  test 'a direct local record link is accepted' do
    record = create_record
    search(record_url(record))
    assert_select "input[name='record_id'][value='#{record.id}']"
  end

  test 'the project scope must belong to the signed in account' do
    record = create_record
    other = User.create!(email: 'other-local-encoder@example.com', password: 'password')
    token = EncoderProjects::CatalogueScope.issue(user: other, project: @project)
    choose(record, token: token)
    assert_response :unprocessable_content
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
  end

  test 'a different existing binding cannot be silently replaced' do
    first = create_record
    choose(first)
    second = create_record
    choose(second)
    assert_equal first.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end
end
