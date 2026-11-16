# frozen_string_literal: true

module EncoderProjects
  class LaunchBinding
    def self.call(data:, launch:, user:, url:)
      project = ProjectRequest.new(data).data
      raise ArgumentError, 'Cette demande appartient à un autre montage.' unless
        project.fetch('project_id') == launch.fetch('project_id')

      Record.transaction do
        record = Record.find(launch.fetch('record_id'))
        LocalRecordSelection.call(user: user, url: url, project: project, record: record)
        Identification.new(user: user, url: url).call(project)
      end
    end
  end
end
