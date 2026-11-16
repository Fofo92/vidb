require 'test_helper'

class EncoderProjects::DesktopTicketTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: 'desktop-ticket@example.com', password: 'password')
    @url = 'https://vidb.test'
  end

  def ticket(action)
    url = EncoderProjects::DesktopTicket.issue(action: action, user: @user, url: @url)
    URI.decode_www_form(URI(url).query).to_h.fetch('ticket')
  end

  test 'all four desktop commands are signed without a record or project association' do
    assert_no_difference ['VideoAsset.count', 'ReconciliationCase.count'] do
      EncoderProjects::DesktopTicket::ACTIONS.each do |action|
        assert_equal({ 'desktop_action' => action },
                     EncoderProjects::DesktopTicket.read(ticket(action), user: @user, url: @url))
      end
    end
  end

  test 'unknown commands tampering other accounts and other servers are rejected' do
    assert_raises(ArgumentError) { ticket('arbitrary_command') }
    signed = ticket('encode_dvd')
    another = User.create!(email: 'other-desktop-ticket@example.com', password: 'password')
    assert_raises(ArgumentError) { EncoderProjects::DesktopTicket.read(signed, user: another, url: @url) }
    assert_raises(ArgumentError) { EncoderProjects::DesktopTicket.read(signed, user: @user, url: 'https://other.test') }
    assert_raises(ArgumentError) { EncoderProjects::DesktopTicket.read("#{signed}x", user: @user, url: @url) }
  end

  test 'a record-preparation signature cannot authorize a general desktop command' do
    purpose = EncoderProjects::LaunchTicket::PURPOSE
    data = { 'action' => 'encode_dvd', 'user_id' => @user.id, 'origin' => @url }
    signed = Rails.application.message_verifier(purpose).generate(data, purpose: purpose)
    assert_raises(ArgumentError) { EncoderProjects::DesktopTicket.read(signed, user: @user, url: @url) }
  end
end
