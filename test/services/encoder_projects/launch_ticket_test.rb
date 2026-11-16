require 'test_helper'

class EncoderProjects::LaunchTicketTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: 'launch-ticket@example.com', password: 'password')
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |row| row.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Film choisi', record_kind: 'standalone_video', language_version: @language)
  end

  def issue(record = @record)
    url = EncoderProjects::LaunchTicket.issue(record: record, user: @user, url: 'https://vidb.test')
    URI.decode_www_form(URI(url).query).to_h.fetch('ticket')
  end

  test 'signed context belongs to its account and a stable project without claiming availability' do
    assert_no_difference ['VideoAsset.count', 'ReconciliationCase.count'] do
      ticket = issue
      data = EncoderProjects::LaunchTicket.read(ticket, user: @user)
      assert_equal @record.id, data['record_id']
      assert_match EncoderProjects::ProjectRequest::UUID, data['project_id']
      assert_equal data, EncoderProjects::LaunchTicket.read(ticket, user: @user)
    end
  end

  test 'tampering another account and another origin all reject the ticket' do
    ticket = issue
    another = User.create!(email: 'launch-ticket-other@example.com', password: 'password')
    assert_raises(ArgumentError) { EncoderProjects::LaunchTicket.read(ticket, user: another) }
    assert_raises(ArgumentError) { EncoderProjects::LaunchTicket.read("#{ticket}changed", user: @user) }
    assert_raises(ArgumentError) do
      EncoderProjects::LaunchTicket.read(ticket, user: @user, url: 'https://other-vidb.test')
    end
  end

  test 'the record choice survives a montage resumed more than a week later' do
    ticket = issue
    travel 8.days do
      assert_equal @record.id, EncoderProjects::LaunchTicket.read(ticket, user: @user)['record_id']
    end
  end

  test 'containers are not treated as autonomous works' do
    record = Record.create!(french_title: 'Une série', record_kind: 'series', language_version: @language)
    assert_not EncoderProjects::LaunchTicket.supported?(record)
    assert_raises(ArgumentError) { issue(record) }
  end

  test 'qualification is checked again after the ticket was issued' do
    ticket = issue
    @record.update!(record_kind: 'series')
    assert_raises(ArgumentError) { EncoderProjects::LaunchTicket.read(ticket, user: @user) }
  end
end
