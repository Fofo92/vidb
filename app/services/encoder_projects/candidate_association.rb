module EncoderProjects
  class CandidateAssociation
    def self.call(user:, item:, token:)
      ReconciliationCase.transaction do
        Record.connection.execute('SELECT pg_advisory_xact_lock(20261024, 2)') if
          Record.connection.adapter_name == 'PostgreSQL'
        record = Record.find(item.payload.fetch('record_id'))
        raise ArgumentError, 'Choisis un film ou un épisode correctement placé.' unless Matcher.qualified?(record)

        next record if already_bound?(item, record)

        approve(user, item, token)
        record
      end
    end

    def self.already_bound?(item, record)
      existing = Binding.current(item.payload.fetch('project_id'))
      return false unless existing

      raise ArgumentError, 'Ce projet est déjà associé à une autre fiche.' unless existing['record_id'] == record.id

      true
    end
    private_class_method :already_bound?

    def self.approve(user, item, token)
      parameters = { axis: 'metadata', ids: [item.id], decision: 'approved', token: token, queue: false,
                     comment: 'Fiche choisie explicitement pour ce montage' }
      ReconciliationWorkbench::CaseReview.new(user: user, parameters: parameters).call
      return if ReconciliationWorkbench::Executor.new.call(item) == 'applied'

      raise ArgumentError, item.reload.error.presence || 'La proposition a changé : relance l’identification.'
    end
    private_class_method :approve
  end
end
