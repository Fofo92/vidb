module EncoderProjects
  class BindingAction
    def call(item)
      payload = item.payload
      record = Record.find(payload.fetch('record_id'))
      raise ArgumentError, 'Fiche à qualifier avant association' unless Matcher.qualified?(record)
      raise ArgumentError, 'Projet invalide' unless ProjectRequest::UUID.match?(payload['project_id'].to_s)

      verify_previous!(payload.fetch('project_id'), record)

      ReconciliationCase.where(rule_key: item.rule_key).where.not(id: item.id)
                        .where("payload ->> 'project_id' = ?", payload.fetch('project_id')).update_all(active: false)
      Binding.issue(payload.fetch('project_id'), record)
    end

    private

    def verify_previous!(project_id, record)
      previous = Binding.current(project_id)
      return unless previous && previous.fetch('record_id') != record.id

      raise ArgumentError, 'Ce projet est déjà associé à une autre fiche'
    end
  end
end
