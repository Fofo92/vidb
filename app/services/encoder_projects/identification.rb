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
      ReconciliationCase.transaction do
        lock_projects!
        previous = Binding.current(request.project_id)
        next identified(previous) if previous

        resolve(request)
      end
    end

    private

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
      { status: 'identified', binding: binding,
        record_title: Record.find(binding.fetch('record_id')).complete_title_with_parents }
    end

    def pending(request, records, observation)
      query = URI.encode_www_form(axis: 'metadata', q: request.project_id)
      review_url = "#{@url}/reconciliation_workbench/reviews?#{query}"
      review_url = "#{@url}/records" if records.empty?
      { status: records.empty? ? 'unmatched' : 'needs_review', review_url: review_url, reason: observation[:reason],
        candidates: records.map do |record|
          { record_id: record.id, title: record.complete_title_with_parents,
            year: record.year, qualified: Matcher.qualified?(record) }
        end }
    end
  end
end
