module EncoderProjects
  # Keeps the old choice until a signed, explicitly confirmed replacement succeeds.
  class AssociationRevision
    def self.call(project, confirmed:)
      expected = project['replace_binding']
      return yield unless expected

      raise ArgumentError, 'Confirme explicitement la révision de l’association.' unless confirmed

      Record.transaction do
        prepare(project, expected)
        yield
      end
    end

    def self.prepare(project, expected)
      lock_projects!
      current = Binding.current(project.fetch('project_id'))
      raise ArgumentError, 'L’association a changé : rouvre le choix de fiche depuis video_encoder.' unless
        expected.is_a?(Hash) && current == expected

      applied(project).update_all(active: false, updated_at: Time.current)
    end
    private_class_method :prepare

    def self.lock_projects!
      Record.connection.execute('SELECT pg_advisory_xact_lock(20261024, 2)') if
        Record.connection.adapter_name == 'PostgreSQL'
    end
    private_class_method :lock_projects!

    def self.applied(project)
      ReconciliationCase.current.where(rule_key: ReconciliationWorkbench::Rules::ENCODER_PROJECT.key,
                                       status: 'applied')
                        .where("payload ->> 'project_id' = ?", project.fetch('project_id'))
    end
    private_class_method :applied
  end
end
