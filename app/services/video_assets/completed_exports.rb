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

    def import(observation)
      matched = observation[:status] == 'episode_candidate' && observation[:title_evidence] == 'title_match'
      raise ArgumentError, 'Épisode sans concordance unique' unless matched && observation.fetch(:candidates, []).one?

      export = CompletedExport.new(observation.fetch(:path)).call
      CompletedExportImport.new(observation, export).call
    rescue StandardError => e
      { status: 'needs_review', reason: e.message }
    end
  end
end
