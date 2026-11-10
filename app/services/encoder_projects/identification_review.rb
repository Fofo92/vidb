require 'uri'

module EncoderProjects
  # Adds a catalogue review link when the identified work can be completed.
  class IdentificationReview
    def initialize(user:, url:)
      @user = user
      @url = url
    end

    def call(result, request)
      return result unless result[:status] == 'identified'

      case result.dig(:metadata, 'record_kind')
      when 'episode' then episode_review(result, request)
      when 'standalone_video' then film_review(result, request)
      else result
      end
    end

    private

    def film_review(result, request)
      return result if %w[year abstract genres countries].all? { |field| result[:metadata][field].present? }

      project = request.data.merge('completion_record_id' => result.dig(:binding, 'record_id'))
      token = CatalogueScope.issue(user: @user, project: project)
      result.merge(review_url: "#{@url}/encoder_projects/catalogue?#{URI.encode_www_form(request_token: token)}")
    end

    def episode_review(result, request)
      token = CatalogueScope.issue(user: @user, project: request.data)
      record = Record.find(result.dig(:binding, 'record_id'))
      query = URI.encode_www_form(request_token: token, enrich: '1', series_id: record.parent.parent.id)
      result.merge(review_url: "#{@url}/encoder_projects/episode?#{query}")
    end
  end
end
