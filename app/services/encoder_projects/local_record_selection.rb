module EncoderProjects
  # Stages a scoped proposal and applies the existing explicitly reviewed association.
  class LocalRecordSelection
    SelectedRecord = Struct.new(:record) do
      def call(_request)
        { status: 'ambiguous_exact', reason: 'Fiche locale choisie explicitement',
          candidates: [{ record_id: record.id, record_kind: record.record_kind }] }
      end
    end

    def self.call(user:, url:, project:, record:, confirmed: false)
      AssociationRevision.call(project, confirmed: confirmed) do
        select_record(user: user, url: url, project: project, record: record)
      end
    end

    def self.select_record(user:, url:, project:, record:)
      raise ArgumentError, 'Qualifie la nature et le placement de cette fiche avant association.' unless
        Matcher.qualified?(record)

      result = Identification.new(user: user, url: url, matcher: SelectedRecord.new(record)).call(project)
      return bound_record(result, record) if result[:status] == 'identified'

      item = ReconciliationCase.current.where(rule_key: ReconciliationWorkbench::Rules::ENCODER_PROJECT.key)
                               .where("payload ->> 'project_id' = ?", project.fetch('project_id'))
                               .where("payload ->> 'record_id' = ?", record.id.to_s).sole
      token = ReconciliationWorkbench::ReviewScope.issue([item], axis: 'metadata')
      CandidateAssociation.call(user: user, item: item, token: token)
    end

    private_class_method :select_record

    def self.bound_record(result, record)
      raise ArgumentError, 'Ce montage est déjà associé à une autre fiche.' unless
        result.dig(:binding, 'record_id') == record.id

      record
    end
    private_class_method :bound_record
  end
end
