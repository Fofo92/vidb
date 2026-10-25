module EncoderProjects
  class CatalogueScope
    PURPOSE = 'encoder-project-catalogue'.freeze

    def self.issue(user:, project:, candidate: nil)
      data = { 'user_id' => user.id, 'project' => project, 'candidate' => candidate }
      Rails.application.message_verifier(PURPOSE).generate(data, purpose: PURPOSE, expires_in: 2.hours)
    end

    def self.read(token, user:)
      data = Rails.application.message_verifier(PURPOSE).verified(token.to_s, purpose: PURPOSE)
      raise ArgumentError, 'Proposition expirée ou autre compte vidb ; relance l’identification.' unless
        data.is_a?(Hash) && data['user_id'] == user.id

      ProjectRequest.new(data.fetch('project'))
      data
    end
  end
end
