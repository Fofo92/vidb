module EncoderProjects
  class EpisodeBinding
    SelectedEpisode = Struct.new(:record) do
      def call(_request)
        { status: 'episode_candidate', title_evidence: 'title_match',
          candidates: [{ record_id: record.id, record_kind: 'episode' }] }
      end
    end

    def initialize(user:, url:)
      @user = user
      @url = url
    end

    def call(project, record)
      result = Identification.new(user: @user, url: @url, matcher: SelectedEpisode.new(record)).call(project)
      return if result[:status] == 'identified' && result.dig(:binding, 'record_id') == record.id

      raise ArgumentError, 'Association à examiner dans la file de consolidation ; aucune nouvelle fiche conservée'
    end
  end
end
