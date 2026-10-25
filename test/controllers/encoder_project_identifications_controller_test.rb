require 'test_helper'
require 'minitest/mock'

class EncoderProjectIdentificationsControllerTest < ActionDispatch::IntegrationTest
  UUID = '4d013c0a-7b54-4a67-aef2-7e1af7f6d410'.freeze

  setup do
    @user = User.create!(email: 'encoder-link@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @record = Record.create!(french_title: 'Film du projet', original_title: '', record_kind: 'standalone_video',
                             year: 2020, language_version: language)
    @config = { 'url' => 'https://vidb.test', 'token' => 'a' * 64, 'user_id' => @user.id }
    @data = { project_id: UUID, project_path: '/videos/Films/Film du projet.json',
              output_path: '/videos/Films/Film du projet.mkv', source_paths: ['/commun/capture.m2t'] }
  end

  def identify(data = @data, token: @config['token'])
    EncoderProjects::Settings.stub(:read, @config) do
      post '/encoder_projects/identify', params: { project: data }, as: :json,
                                         headers: { 'Authorization' => "Bearer #{token}" }
    end
  end

  test 'authentication is required before any catalogue access or proposal write' do
    identify(token: 'wrong')
    assert_response :unauthorized
    assert_equal 0, ReconciliationCase.count
    assert_equal 0, ReconciliationCaseReview.count
  end

  test 'unique film association changes no metadata availability or video asset' do
    before = @record.attributes
    identify
    assert_response :success
    body = response.parsed_body
    assert_equal 'identified', body['status']
    assert_equal @record.id, body.dig('binding', 'record_id')
    assert_equal before, @record.reload.attributes
    assert_equal 0, VideoAsset.count
    assert_equal 0, ReconciliationRun.count
    assert_equal 'applied', ReconciliationCase.sole.status
    assert_equal @user.id, ReconciliationCaseReview.sole.user_id
    identify
    assert_equal 1, ReconciliationCase.count
    assert_equal 1, ReconciliationCaseReview.count
  end

  test 'homonyms become proposals and require one explicit choice' do
    other = Record.create!(french_title: @record.french_title, record_kind: 'standalone_video',
                           year: 1950, language_version: @record.language_version)
    identify
    assert_response :success
    assert_equal 'needs_review', response.parsed_body['status']
    assert_equal [@record.id, other.id].sort, response.parsed_body['candidates'].map { |item| item['record_id'] }.sort
    assert_equal 2, ReconciliationCase.current.count
    assert_equal 0, ReconciliationCaseReview.count
    assert_nil EncoderProjects::Binding.current(UUID)
    items = ReconciliationCase.current.to_a
    token = ReconciliationWorkbench::ReviewScope.issue(items, axis: 'metadata')
    assert_raises(ArgumentError) do
      ReconciliationWorkbench::CaseReview.new(user: @user, parameters: {
        axis: 'metadata', ids: items.map(&:id), decision: 'approved', token: token }).call
    end
    chosen = items.find { |item| item.payload['record_id'] == other.id }
    ReconciliationWorkbench::CaseReview.new(user: @user, parameters: {
      axis: 'metadata', ids: [chosen.id], decision: 'approved', token: token, queue: false }).call
    assert_equal 'applied', ReconciliationWorkbench::Executor.new.call(chosen)
    identify
    assert_equal 'identified', response.parsed_body['status']
    assert_equal other.id, response.parsed_body.dig('binding', 'record_id')
  end

  test 'a family approval cannot choose an ambiguous project candidate' do
    Record.create!(french_title: @record.french_title, record_kind: 'standalone_video',
                   language_version: @record.language_version)
    identify
    rule = ReconciliationWorkbench::Rules::ENCODER_PROJECT
    ReconciliationRuleDecision.create!(rule_key: rule.key, rule_version: rule.version, decision: 'approved',
                                      case_fingerprints: ReconciliationCase.pluck(:fingerprint))
    assert ReconciliationCase.current.all? { |item| !item.permitted? }
  end

  test 'a deferred project candidate is not approved again automatically on save' do
    matcher = Object.new
    id = @record.id
    matcher.define_singleton_method(:call) do |_request|
      { status: 'ambiguous_exact', candidates: [{ record_id: id, record_kind: 'standalone_video' }] }
    end
    EncoderProjects::Matcher.stub(:new, -> { matcher }) { identify }
    assert_response :success
    item = ReconciliationCase.current.sole
    token = ReconciliationWorkbench::ReviewScope.issue([item], axis: 'metadata')
    ReconciliationWorkbench::CaseReview.new(user: @user, parameters: {
      axis: 'metadata', ids: [item.id], decision: 'deferred', token: token }).call
    identify
    assert_equal 'needs_review', response.parsed_body['status']
    assert_equal 'deferred', ReconciliationCaseReview.sole.decision
    assert_nil EncoderProjects::Binding.current(UUID)
  end

  test 'an episode title alone cannot establish an automatic global homonym match' do
    series = Record.create!(french_title: 'Série unique', record_kind: 'series', language_version: @record.language_version)
    season = series.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season',
                                     language_version: @record.language_version)
    episode = season.children.create!(french_title: 'Épisode rare', rank: 1, record_kind: 'episode',
                                      language_version: @record.language_version)
    identify(@data.merge(project_path: '/videos/Films/Épisode rare.json', output_path: '/videos/Films/Épisode rare.mkv'))
    assert_equal 'needs_review', response.parsed_body['status']
    assert_equal episode.id, response.parsed_body['candidates'].sole['record_id']
    assert_nil EncoderProjects::Binding.current(UUID)
  end

  test 'scoped episode identity can be established before its output exists' do
    series = Record.create!(french_title: 'Série unique', record_kind: 'series', language_version: @record.language_version)
    season = series.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season',
                                     language_version: @record.language_version)
    episode = season.children.create!(french_title: 'Épisode rare', rank: 1, record_kind: 'episode',
                                      language_version: @record.language_version)
    stem = '/videos/Séries TV/Série unique/Saison 01/S01 E01 - Épisode rare'
    identify(@data.merge(project_path: "#{stem}.json", output_path: "#{stem}.mkv"))
    assert_equal 'identified', response.parsed_body['status']
    assert_equal episode.id, response.parsed_body.dig('binding', 'record_id')
    assert_equal 0, VideoAsset.count
  end

  test 'invalid paths and identifiers write no proposals' do
    [@data.merge(project_id: 'invalid'), @data.merge(output_path: '/tmp/film.mkv'),
     @data.merge(output_path: '/videos/../etc/film.mkv')].each do |data|
      identify(data)
      assert_response :unprocessable_content
    end
    assert_equal 0, ReconciliationCase.count
    assert_equal 0, ReconciliationCaseReview.count
  end

  test 'an unknown work remains pending rather than creating a guessed catalogue record' do
    identify(@data.merge(project_path: '/videos/Œuvre absente.json', output_path: '/videos/Œuvre absente.mkv'))
    assert_response :success
    assert_equal 'unmatched', response.parsed_body['status']
    assert_equal 1, Record.count
    assert_equal 0, VideoAsset.count
  end
end
