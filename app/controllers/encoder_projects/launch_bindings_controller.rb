# frozen_string_literal: true

module EncoderProjects
  # Reuses the existing bridge authentication, independent of browser cookies.
  class LaunchBindingsController < IdentificationsController
    def create
      raise ArgumentError, 'Demande limitée à 64 Ko' if request.raw_post.bytesize > 65_536

      return render json: desktop_action if params[:desktop_token]

      launch = LaunchTicket.read(params.require(:launch_token), user: @operator, url: @configuration.fetch('url'))
      return render json: launch.slice('project_id', 'record_id', 'record_title', 'source_copy') unless params[:project]

      render json: bind_project(launch)
    rescue ArgumentError, KeyError, ActiveRecord::RecordNotFound, ActiveRecord::RecordInvalid => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def desktop_action
      raise ArgumentError, 'Une commande de montage ne peut pas associer une fiche.' if
        params[:project] || params[:launch_token]

      DesktopTicket.read(params.require(:desktop_token), user: @operator, url: @configuration.fetch('url'))
    end

    def bind_project(launch)
      data = params.require(:project).permit(:project_id, :project_path, :output_path,
                                             :language_hint, source_paths: []).to_h
      validate_copy_source!(launch, data)
      launch = launch.merge('project_id' => data['project_id']) if launch['source_copy']
      LaunchBinding.call(data: data, launch: launch, user: @operator, url: @configuration.fetch('url'))
    end

    def validate_copy_source!(launch, data)
      return unless launch['source_copy']
      return if data['source_paths'] == [launch.fetch('source_copy').fetch('path')]

      raise ArgumentError, 'La copie source ne correspond plus à la demande vidb.'
    end
  end
end
