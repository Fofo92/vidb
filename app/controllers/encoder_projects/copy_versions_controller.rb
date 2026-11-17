# frozen_string_literal: true

module EncoderProjects
  class CopyVersionsController < ApplicationController
    def show
      @record = Record.find(params[:record_id])
      asset = @record.video_assets.find(params[:id])
      verify_operator!
      @launch_url = LaunchTicket.issue(record: @record, user: current_user,
                                       url: request.base_url, source_copy: asset)
    rescue ArgumentError, KeyError, JSON::ParserError => e
      redirect_to record_path(@record), alert: e.message
    end

    private

    def verify_operator!
      return if Settings.read.fetch('user_id') == current_user.id

      raise ArgumentError, 'La passerelle video_encoder est configurée pour un autre compte.'
    end
  end
end
