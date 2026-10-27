require 'test_helper'

class EncoderProjectAssociationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'association-project@example.com', password: 'password')
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Film à choisir', record_kind: 'standalone_video',
                             language_version: @language)
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/capture.json',
                 'output_path' => '/videos/capture.mkv', 'source_paths' => ['/commun/capture.m2t'] }
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    sign_in @user
  end

  def propose(record = @record, project = @project)
    matcher = Object.new
    matcher.define_singleton_method(:call) do |_request|
      { status: 'ambiguous_exact', candidates: [{ record_id: record.id, record_kind: record.record_kind }] }
    end
    EncoderProjects::Identification.new(user: @user, url: 'https://vidb.test', matcher: matcher).call(project)
    ReconciliationCase.current.where("payload ->> 'project_id' = ?", project.fetch('project_id')).sole
  end

  test 'only the current project is displayed even when another project proposes the same record' do
    own = propose
    other_project = @project.merge('project_id' => SecureRandom.uuid)
    other = propose(@record, other_project)
    get encoder_projects_association_path, params: { request_token: @token }
    assert_response :success
    assert_select 'input[name="case_id"]', count: 1
    assert_select "input[name='case_id'][value='#{own.id}']"
    assert_select "input[name='case_id'][value='#{other.id}']", count: 0
  end

  test 'an explicit choice binds the project without a copy or metadata change' do
    item = propose
    before = @record.attributes
    token = ReconciliationWorkbench::ReviewScope.issue([item], axis: 'metadata')
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      post encoder_projects_association_path,
           params: { request_token: @token, case_id: item.id, review_token: token }
    end
    assert_redirected_to record_path(@record, encoder_prepared: 1)
    assert_equal @record.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
    assert_equal before, @record.reload.attributes
  end

  test 'a series offers season and episode selection but cannot be directly associated' do
    series = Record.create!(french_title: 'Gerta', record_kind: 'series', language_version: @language)
    item = propose(series)
    get encoder_projects_association_path, params: { request_token: @token }
    assert_select 'input[name="case_id"]', count: 0
    assert_select 'input[name="season_number"]'
    assert_select 'input[name="episode_number"]'
    token = ReconciliationWorkbench::ReviewScope.issue([item], axis: 'metadata')
    post encoder_projects_association_path, params: { request_token: @token, case_id: item.id, review_token: token }
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
  end

  test 'a proposal belonging to another project is rejected' do
    item = propose(@record, @project.merge('project_id' => SecureRandom.uuid))
    token = ReconciliationWorkbench::ReviewScope.issue([item], axis: 'metadata')
    post encoder_projects_association_path, params: { request_token: @token, case_id: item.id, review_token: token }
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
  end
end
