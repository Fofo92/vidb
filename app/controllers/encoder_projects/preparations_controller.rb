# frozen_string_literal: true

module EncoderProjects
  class PreparationsController < ApplicationController
    def show
      @record = Record.find(params[:record_id])
      configuration = Settings.read
      raise ArgumentError, 'La passerelle video_encoder est configurée pour un autre compte.' unless
        configuration.fetch('user_id') == current_user.id

      @launch_url = LaunchTicket.issue(record: @record, user: current_user, url: request.base_url)
    rescue ArgumentError, KeyError, JSON::ParserError => e
      redirect_to record_path(@record), alert: e.message
    end
  end
end
