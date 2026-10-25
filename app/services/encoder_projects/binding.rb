module EncoderProjects
  class Binding
    PURPOSE = 'vidb-encoder-project-binding'.freeze

    def self.issue(project_id, record)
      token = Rails.application.message_verifier(PURPOSE).generate(
        { 'project_id' => project_id, 'record_id' => record.id }, purpose: PURPOSE
      )
      { 'project_id' => project_id, 'record_id' => record.id, 'binding_token' => token }
    end

    def self.current(project_id)
      item = ReconciliationCase.current.where(rule_key: ReconciliationWorkbench::Rules::ENCODER_PROJECT.key,
                                              status: 'applied').where("payload ->> 'project_id' = ?", project_id)
                               .order(id: :desc).first
      item&.result&.slice('project_id', 'record_id', 'binding_token')
    end

    def self.pending?(project_id)
      return false unless ProjectRequest::UUID.match?(project_id.to_s)

      ReconciliationCase.current.where(rule_key: ReconciliationWorkbench::Rules::ENCODER_PROJECT.key,
                                       status: %w[pending blocked])
                        .where("payload ->> 'project_id' = ?", project_id).exists?
    end

    def self.record_for(receipt)
      data = receipt['vidb']
      project_id = valid_project_id(receipt['project_id'], data)
      return unless project_id

      binding = data.is_a?(Hash) && data['binding_token'].present? ? verify(data, project_id) : current(project_id)
      Record.find(binding.fetch('record_id')) if binding
    end

    def self.valid_project_id(project_id, data)
      return project_id if ProjectRequest::UUID.match?(project_id.to_s)
      return unless data.is_a?(Hash) && data['binding_token'].present?

      raise ArgumentError, 'Identifiant de projet invalide pour une liaison signée'
    end

    def self.verify(data, project_id)
      signed = Rails.application.message_verifier(PURPOSE).verified(data['binding_token'], purpose: PURPOSE)
      valid = signed.is_a?(Hash) && signed['project_id'] == project_id &&
              signed['record_id'].is_a?(Integer) && signed['record_id'] == data['record_id']
      raise ArgumentError, 'Liaison vidb du projet invalide' unless valid

      signed
    end
  end
end
