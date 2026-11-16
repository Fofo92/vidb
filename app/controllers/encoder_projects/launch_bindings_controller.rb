# frozen_string_literal: true

module EncoderProjects
  # Reuses the existing bridge authentication, independent of browser cookies.
  class LaunchBindingsController < IdentificationsController
    def create
      raise ArgumentError, 'Demande limitée à 64 Ko' if request.raw_post.bytesize > 65_536

      launch = LaunchTicket.read(params.require(:launch_token), user: @operator, url: @configuration.fetch('url'))
      return render json: launch.slice('project_id', 'record_id', 'record_title') unless params[:project]

      render json: bind_project(launch)
    rescue ArgumentError, KeyError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def bind_project(launch)
      data = params.require(:project).permit(:project_id, :project_path, :output_path,
                                             :language_hint, source_paths: []).to_h
      LaunchBinding.call(data: data, launch: launch, user: @operator, url: @configuration.fetch('url'))
    end
  end
end
