require 'uri'

module EncoderProjects
  class Identification
    def initialize(user:, url:, matcher: Matcher.new)
      @user = user
      @url = url
      @matcher = matcher
    end

    def call(data)
      request = ProjectRequest.new(data)
      @project_data = request.data
      result = ReconciliationCase.transaction do
        lock_projects!
        previous = Binding.current(request.project_id)
        next identified(previous) if previous

        resolve(request)
      end
      episode_review(result, request)
    end

    private

    def episode_review(result, request)
      return result unless result[:status] == 'identified' && result.dig(:metadata, 'record_kind') == 'episode'

      token = CatalogueScope.issue(user: @user, project: request.data)
      record = Record.find(result.dig(:binding, 'record_id'))
      query = URI.encode_www_form(request_token: token, enrich: '1', series_id: record.parent.parent.id)
      result.merge(review_url: "#{@url}/encoder_projects/episode?#{query}")
    end

    def lock_projects!
      return unless Record.connection.adapter_name == 'PostgreSQL'

      Record.connection.execute('SELECT pg_advisory_xact_lock(20261024, 2)')
    end

    def resolve(request)
      observation = @matcher.call(request)
      records = observation.fetch(:candidates, []).first(20).filter_map { |row| Record.find_by(id: row[:record_id]) }
      items = records.map { |record| proposal(request, record, observation) }
      if Matcher.certain?(observation) && records.one? && Matcher.qualified?(records.first)
        return accept(items.sole) || pending(request, records, observation)
      end

      pending(request, records, observation)
    end

    def proposal(request, record, observation)
      states = [*record.ancestors.to_a, record].to_h do |item|
        [item.id.to_s, ReconciliationWorkbench::Snapshot.record(item)]
      end
      payload = request.data.merge('record_id' => record.id, 'title' => record.complete_title_with_parents,
                                   'path' => request.data.fetch('output_path'),
                                   'reason' => reason(record, observation),
                                   'file_count' => 0, 'records' => states, 'exclusive_group' => request.project_id)
      key = "encoder:#{request.project_id}:record:#{record.id}"
      ReconciliationWorkbench::CaseStore.propose(rule: ReconciliationWorkbench::Rules::ENCODER_PROJECT,
                                                 key: key, payload: payload)
    end

    def reason(record, observation)
      basis = observation[:reason] || observation[:title_evidence] || observation[:status]
      qualifier = Matcher.qualified?(record) ? '' : ' Nature ou placement à consolider avant association.'
      "Fiche n° #{record.id}, année #{record.year || 'non renseignée'}. Rapprochement : #{basis}.#{qualifier}"
    end

    def accept(item)
      review = ReconciliationCaseReview.for(item).first
      return if review && !review.permits?(item)

      authorize_unique(item) unless review
      return unless ReconciliationWorkbench::Executor.new.call(item) == 'applied'

      identified(item.reload.result)
    end

    def authorize_unique(item)
      token = ReconciliationWorkbench::ReviewScope.issue([item], axis: 'metadata')
      parameters = { axis: 'metadata', ids: [item.id], decision: 'approved', token: token, queue: false,
                     comment: 'Correspondance unique à la création du projet' }
      ReconciliationWorkbench::CaseReview.new(user: @user, parameters: parameters).call
    end

    def identified(binding)
      record = Record.find(binding.fetch('record_id'))
      { status: 'identified', binding: binding,
        record_title: record.complete_title_with_parents, metadata: RecordPresentation.call(record),
        selection_url: selection_url(binding) }
    end

    def selection_url(binding)
      project = @project_data.merge('replace_binding' => binding.slice('project_id', 'record_id', 'binding_token'))
      token = CatalogueScope.issue(user: @user, project: project)
      "#{@url}/encoder_projects/local_records?#{URI.encode_www_form(request_token: token,
                                                                    q: binding.fetch('record_id'))}"
    end

    def pending(request, records, observation)
      token = CatalogueScope.issue(user: @user, project: request.data)
      query = URI.encode_www_form(request_token: token)
      review_url = "#{@url}/encoder_projects/association?#{query}"
      review_url = catalogue_url(request) if records.empty?
      { status: records.empty? ? 'unmatched' : 'needs_review', review_url: review_url, reason: observation[:reason],
        candidates: records.map do |record|
          { record_id: record.id, title: record.complete_title_with_parents,
            year: record.year, qualified: Matcher.qualified?(record) }
        end }
    end

    def catalogue_url(request)
      token = CatalogueScope.issue(user: @user, project: request.data)
      page = EpisodeRequest.match?(request.data) ? 'episode' : 'catalogue'
      "#{@url}/encoder_projects/#{page}?#{URI.encode_www_form(request_token: token)}"
    end
  end
end
