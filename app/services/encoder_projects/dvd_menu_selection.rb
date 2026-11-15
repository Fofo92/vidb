# frozen_string_literal: true

module EncoderProjects
  class DvdMenuSelection
    def self.call(user:, url:, project:, record:, edition_id: nil)
      Record.transaction do
        edition = DvdEdition.find(edition_id) if edition_id.present?
        validate_edition!(edition, record)
        LocalRecordSelection.call(user: user, url: url, project: project, record: record)
        DvdOwnership.confirm!(edition: edition, record: record) if edition
      end
    end

    def self.validate_edition!(edition, record)
      return unless edition
      return if edition.record.subtree.exists?(id: record.id)

      raise ArgumentError, "Cet épisode n’appartient pas à cette édition DVD."
    end
    private_class_method :validate_edition!
  end
end
