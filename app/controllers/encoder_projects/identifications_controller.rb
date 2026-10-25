module EncoderProjects
  class IdentificationsController < ActionController::API
    before_action :authenticate_encoder

    def create
      raise ArgumentError, 'Demande de projet limitée à 64 Ko' if request.raw_post.bytesize > 65_536

      data = params.require(:project).permit(:project_id, :project_path, :output_path, source_paths: []).to_h
      render json: Identification.new(user: @operator, url: @configuration.fetch('url')).call(data)
    rescue ArgumentError, KeyError, ActiveRecord::RecordNotFound => e
      render json: { error: e.message }, status: :unprocessable_content
    end

    private

    def authenticate_encoder
      @configuration = Settings.read
      received = request.authorization.to_s.delete_prefix('Bearer ')
      return head :unauthorized unless ActiveSupport::SecurityUtils.secure_compare(@configuration.fetch('token'),
                                                                                   received)

      @operator = User.find(@configuration.fetch('user_id'))
    rescue ArgumentError, KeyError, JSON::ParserError, ActiveRecord::RecordNotFound
      head :service_unavailable
    end
  end
end
