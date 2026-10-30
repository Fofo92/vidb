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

  test 'a local series offers an episode choice with the same signed montage identity' do
    series = create_record(kind: 'series')
    @project['source_paths'] = ['/commun/to_be_cut/Serie - S06 E15 - Episode.m2t']
    @token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    assert_no_difference ['Record.count', 'VideoAsset.count', 'ReconciliationCase.count'] do
      search(series.id.to_s)
    end
    assert_select "form[action='#{encoder_projects_episode_path}'][method='get']" do
      assert_select "input[name='series_id'][value='#{series.id}']"
      assert_select "input[name='season_number'][value='6']"
      assert_select "input[name='episode_number'][value='15']"
      assert_select "input[name='enrich'][value='0']"
      assert_select 'input[name="request_token"]' do |inputs|
        project = EncoderProjects::CatalogueScope.read(inputs.sole['value'], user: @user).fetch('project')
        assert_equal @project, project.except('episode_target')
        assert_equal({ 'season' => 6, 'episode' => 15 }, project['episode_target'])
      end
    end
    assert_select "form[action='#{encoder_projects_local_records_path}'][method='post']", count: 0
  end

  test 'a local season opens the episode choice for its parent series including season zero' do
    series = create_record(kind: 'series')
    season = series.children.create!(french_title: 'Saison 00', record_kind: 'season', rank: 0,
                                     language_version: @language)
    search(season.id.to_s)
    assert_select "form[action='#{encoder_projects_episode_path}']" do
      assert_select "input[name='series_id'][value='#{series.id}']"
      assert_select "input[name='season_number'][value='0']"
      assert_select "input[name='episode_number'][value='1']"
    end
  end

  test 'opening the selected episode reuses local defaults without creating anything' do
    series = create_record(kind: 'series')
    season = series.children.create!(french_title: 'Saison 02', record_kind: 'season', rank: 2,
                                     language_version: @language)
    episode = season.children.create!(french_title: 'Épisode déjà créé', record_kind: 'episode', rank: 3,
                                      language_version: @language)
    project = @project.merge('episode_target' => { 'season' => 2, 'episode' => 3 })
    token = EncoderProjects::CatalogueScope.issue(user: @user, project: project)
    assert_no_difference ['Record.count', 'VideoAsset.count', 'ReconciliationCase.count'] do
      get encoder_projects_episode_path, params: { request_token: token, series_id: series.id.to_s,
                                                  q: series.french_title, season_number: '2', episode_number: '3', enrich: '0' }
    end
    assert_response :success
    assert_includes response.body, episode.french_title
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
  end


  def revision_token
    result = EncoderProjects::Identification.new(user: @user, url: 'https://www.example.com').call(@project)
    uri = URI(result.fetch(:selection_url))
    URI.decode_www_form(uri.query).to_h.fetch('request_token')
  end

  test 'confirmed revision replaces the binding while preserving its applied history and old signed receipts' do
    first = create_record
    choose(first)
    previous = EncoderProjects::Binding.current(@project['project_id'])
    token = revision_token
    second = create_record
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      post encoder_projects_local_records_path, params: {
        request_token: token, record_id: second.id, confirm_replacement: '1'
      }
    end
    assert_redirected_to record_path(second, encoder_prepared: 1)
    assert_equal second.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
    assert_equal first.id, EncoderProjects::Binding.verify(previous, @project['project_id'])['record_id']
    assert ReconciliationCase.where(status: 'applied', active: false)
                             .where("payload ->> 'project_id' = ?", @project['project_id']).exists?
  end

  test 'revision is not applied without explicit confirmation' do
    first = create_record
    choose(first)
    token = revision_token
    second = create_record
    post encoder_projects_local_records_path, params: { request_token: token, record_id: second.id }
    assert_equal first.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end

  test 'a failed revision rolls back the previous association' do
    first = create_record
    choose(first)
    token = revision_token
    invalid = create_record(kind: 'undetermined')
    post encoder_projects_local_records_path, params: {
      request_token: token, record_id: invalid.id, confirm_replacement: '1'
    }
    assert_equal first.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end

  test 'a stale revision cannot overwrite a newer choice' do
    first = create_record
    choose(first)
    stale = revision_token
    second = create_record
    post encoder_projects_local_records_path, params: {
      request_token: stale, record_id: second.id, confirm_replacement: '1'
    }
    third = create_record
    post encoder_projects_local_records_path, params: {
      request_token: stale, record_id: third.id, confirm_replacement: '1'
    }
    assert_equal second.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end

end


