require 'test_helper'

class ReconciliationReviewsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'consolidation-ui@example.com', password: 'password')
    sign_in @user
    language = LanguageVersion.create!(short_name: 'IND', long_name: 'Indéterminée')
    @root = Record.create!(french_title: 'Série de test', record_kind: 'series', language_version: language)
    @child = @root.children.create!(french_title: 'Épisode de test', record_kind: 'episode', rank: 1,
                                    language_version: language)
    @rule = ReconciliationWorkbench::Rules.fetch('sourced_year_fill')
    @item = ReconciliationWorkbench::CaseStore.propose(rule: @rule, key: "record:#{@child.id}:year", payload: {
      'record_id' => @child.id, 'title' => @child.french_title, 'field' => 'year', 'before' => nil, 'value' => 2020,
      'sources' => ['https://example.org/source'], 'records' => {}, 'file_count' => 0 })
  end

  test 'queue shows explicit decisions before after values and source links without checked defaults' do
    get reconciliation_workbench_reviews_path(axis: 'metadata')
    assert_response :success
    assert_select '[data-consolidation-queue]'
    assert_select "[data-consolidation-case='#{@item.id}']" do
      assert_select 'input[type=checkbox][name="case_ids[]"]:not([checked])', count: 1
      assert_select 'a[href="https://example.org/source"]'
      assert_select 'div', text: /Actuel.*Non renseigné/m
      assert_select 'div', text: /Proposé.*2020/m
    end
    assert_select 'input[name=review_token]'
    assert_select 'button[value=approved]'
    assert_select 'button[value=deferred]'
    assert_select 'button[value=rejected]'
    assert_equal 0, ReconciliationCaseReview.count
  end

  test 'filtering by tree includes descendants and preserves query criteria' do
    get reconciliation_workbench_reviews_path(axis: 'metadata', tree_id: @root.id, q: 'Épisode')
    assert_response :success
    assert_select "[data-consolidation-case='#{@item.id}']"
    assert_select "input[name=tree_id][value='#{@root.id}']"
    assert_select 'input[name=q][value="Épisode"]'
  end

  test 'metadata and disk proposals stay on separate axes' do
    disk = ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::DISK,
      key: '/videos/Drama/episode.mkv', payload: { 'record_id' => @child.id, 'title' => @child.french_title,
      'path' => '/videos/Drama/episode.mkv', 'records' => {} })
    get reconciliation_workbench_reviews_path(axis: 'metadata')
    assert_select "[data-consolidation-case='#{disk.id}']", count: 0
    get reconciliation_workbench_reviews_path(axis: 'disk', q: '/videos/Drama')
    assert_select "[data-consolidation-case='#{disk.id}']", count: 1
    assert_select "[data-consolidation-case='#{@item.id}']", count: 0
  end

  test 'submitting selected cases records their decisions and queues one application' do
    token = ReconciliationWorkbench::ReviewScope.issue([@item], axis: 'metadata')
    post reconciliation_workbench_reviews_path, params: {
      axis: 'metadata', decision: 'approved', review_token: token, case_ids: [@item.id], tree_id: @root.id }
    assert_redirected_to reconciliation_workbench_reviews_path(axis: 'metadata', tree_id: @root.id)
    assert @item.permitted?
    assert_equal @user.id, ReconciliationCaseReview.sole.user_id
    assert_equal 1, ReconciliationRun.count
    assert_equal 'pending', @item.reload.status
  end

  test 'invalid tokens and empty selections produce a message without writing decisions' do
    post reconciliation_workbench_reviews_path, params: { axis: 'metadata', decision: 'approved',
                                                         review_token: 'invalid', case_ids: [@item.id] }
    assert_response :redirect
    assert_equal 0, ReconciliationCaseReview.count
    assert_equal 0, ReconciliationRun.count
    post reconciliation_workbench_reviews_path, params: { axis: 'metadata', decision: 'approved', case_ids: [] }
    assert_response :redirect
    assert_equal 0, ReconciliationRun.count
  end

  test 'deferred cases remain visible through their dedicated filter after replanning' do
    token = ReconciliationWorkbench::ReviewScope.issue([@item], axis: 'metadata')
    post reconciliation_workbench_reviews_path, params: { axis: 'metadata', decision: 'deferred',
                                                         review_token: token, case_ids: [@item.id] }
    @item = ReconciliationWorkbench::CaseStore.propose(rule: @rule, key: @item.case_key,
      payload: @item.payload.merge('value' => 2021))
    get reconciliation_workbench_reviews_path(axis: 'metadata')
    assert_select "[data-consolidation-case='#{@item.id}']", count: 0
    get reconciliation_workbench_reviews_path(axis: 'metadata', state: 'deferred')
    assert_select "[data-consolidation-case='#{@item.id}']", count: 1
    assert_not @item.permitted?
  end

  test 'decisions require authentication' do
    sign_out @user
    get reconciliation_workbench_reviews_path
    assert_redirected_to new_user_session_url
    assert_equal 0, ReconciliationCaseReview.count
  end
end
