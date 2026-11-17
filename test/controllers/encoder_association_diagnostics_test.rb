require 'test_helper'

class EncoderAssociationDiagnosticsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'association-diagnostics@example.com', password: 'password')
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Gerta <script>test</script>', record_kind: 'undetermined',
                             language_version: @language)
    @rule = ReconciliationWorkbench::Rules::ENCODER_PROJECT
    @item = ReconciliationWorkbench::CaseStore.propose(rule: @rule, key: 'diagnostic:project', payload: {
      'record_id' => @record.id, 'title' => @record.french_title, 'path' => '/videos/Gerta.mkv',
      'file_count' => 0, 'records' => {},
      'reason' => 'Rapprochement : exact. Nature ou placement à consolider avant association.' })
    sign_in @user
  end

  test 'existing proposals display a current cause and correction link without changing the case or record' do
    before = [@record.attributes, @item.attributes]
    assert_no_difference ['VideoAsset.count', 'ReconciliationRun.count'] do
      get reconciliation_workbench_family_path(@rule.key)
    end
    assert_response :success
    assert_select '[data-encoder-association-diagnostic]' do
      assert_select 'p', text: /Nature non renseignée/
      assert_select "a[href='#{record_path(@record)}']", text: /Fiche n° #{@record.id}/
      assert_select "a[href='#{edit_record_path(@record)}']", text: 'Corriger la nature'
      assert_select 'script', count: 0
    end
    assert_not_includes response.body, 'Nature ou placement à consolider avant association.'
    assert_equal before, [@record.reload.attributes, @item.reload.attributes]
  end

  test 'corrected records no longer show an old structural blocker or authorize a stale proposal' do
    @record.update!(record_kind: 'standalone_video')
    fingerprint = @item.fingerprint
    get reconciliation_workbench_family_path(@rule.key)
    assert_select '[data-encoder-association-diagnostic] p', text: /Structure désormais compatible/
    assert_not_includes response.body, 'Association bloquée'
    assert_equal fingerprint, @item.reload.fingerprint
    assert_equal 'pending', @item.status
    assert_not @item.permitted?
    assert_equal 0, ReconciliationRun.count
  end

  test 'the link targets an unspecified parent and updates when that parent is qualified' do
    parent = Record.create!(french_title: 'Parent', record_kind: 'undetermined', language_version: @language)
    @record.update!(record_kind: 'standalone_video', parent: parent)
    get reconciliation_workbench_family_path(@rule.key)
    assert_select '[data-encoder-association-diagnostic]' do
      assert_select "a[href='#{edit_record_path(parent)}']", text: 'Corriger la nature'
      assert_select "a[href='#{edit_record_path(@record)}']", count: 0
    end
    parent.update!(record_kind: 'collection')
    get reconciliation_workbench_family_path(@rule.key)
    assert_select '[data-encoder-association-diagnostic] p', text: /Structure désormais compatible/
  end

  test 'incompatible placement links to the move form and retains the current parent' do
    parent = Record.create!(french_title: 'Parent', record_kind: 'collection', language_version: @language)
    @record.update!(record_kind: 'standalone_video', parent: parent)
    parent.update_columns(record_kind: 'series')
    get reconciliation_workbench_family_path(@rule.key)
    assert_select '[data-encoder-association-diagnostic]' do
      assert_select 'p', text: /Placement incompatible/
      assert_select "a[href='#{edit_record_hierarchy_placement_path(@record)}']", text: 'Corriger le placement'
    end
    assert_equal parent.id, @record.reload.parent_id
  end
end
