# frozen_string_literal: true

class MontagesController < ApplicationController
  def show
    configuration = EncoderProjects::Settings.read
    raise ArgumentError, 'La passerelle video_encoder est configurée pour un autre compte.' unless
      configuration.fetch('user_id') == current_user.id

    @actions = EncoderProjects::DesktopTicket::ACTIONS.to_h { |action| [action, launch_url(action)] }
  rescue ArgumentError, KeyError, JSON::ParserError => e
    @configuration_error = e.message
  end

  private

  def launch_url(action)
    EncoderProjects::DesktopTicket.issue(action: action, user: current_user, url: request.base_url)
  end
end
