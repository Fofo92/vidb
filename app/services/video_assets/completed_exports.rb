# frozen_string_literal: true

module VideoAssets
  class CompletedExports
    def call(report)
      report.fetch(:observations, []).filter_map do |observation|
        path = observation.fetch(:path)
        next unless File.file?("#{path}#{CompletedExport::SUFFIX}")

        import(observation).merge(path: path)
      end
    end

    private

    def validate_legacy_match!(observation)
      matched = observation[:status] == 'episode_candidate' && observation[:title_evidence] == 'title_match'
      return if matched && observation.fetch(:candidates, []).one?

      raise ArgumentError, 'Export sans liaison vidb validée ni concordance unique'
    end

    def bound_observation(observation, record)
      fields = record.attributes.symbolize_keys.slice(:ancestry, :rank, :french_title, :original_title)
      observation.merge(candidates: [fields.merge(record_id: record.id)])
    end

    def bound_record(receipt)
      record = EncoderProjects::Binding.record_for(receipt) || EncoderProjects::Resume.call(receipt)
      return record if record
      return unless EncoderProjects::Binding.pending?(receipt['project_id'])

      raise ArgumentError, 'Identification du projet à valider dans vidb'
    end

    def import(observation)
      export = CompletedExport.new(observation.fetch(:path)).call
      record = bound_record(export.fetch(:receipt))
      if record
        observation = bound_observation(observation, record)
      else
        validate_legacy_match!(observation)
      end
      CompletedExportImport.new(observation, export).call
    rescue StandardError => e
      { status: 'needs_review', reason: e.message }
    end
  end
end
