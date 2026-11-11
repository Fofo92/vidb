require 'test_helper'

class RecordViewingChoicesTest < ActionView::TestCase
  helper RecordChildQualificationsHelper

  test 'viewing offers only yes and no while verification retains unknown' do
    assert_equal [['Oui', 'yes'], ['Non', 'no']], child_qualification_options('is_seen')
    assert_includes child_qualification_options('is_checked'), ['Inconnu', 'unknown']
    render partial: 'records/state_choices', locals: { field: :is_seen, bulk: true }
    assert_select 'button[data-value=yes]', count: 1
    assert_select 'button[data-value=no]', count: 1
    assert_select 'button[data-value=unknown]', count: 0
  end
end
