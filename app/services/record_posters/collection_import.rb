# frozen_string_literal: true

module RecordPosters
  # Persist only poster evidence; project bindings and record editorial fields remain untouched.
  class CollectionImport
    def initialize(client:, fetcher: Fetch.new)
      @planner = CollectionPlan.new(client: client)
      @fetcher = fetcher
    end

    def call(record, expected:)
      result = record.with_lock do
        current = @planner.call(record.reload)
        next current unless %w[ready identified].include?(current[:status])
        next { status: 'changed', reason: 'Le bilan a changé ; relancer un aperçu' } unless current == expected

        remember(record, current)
      end
      return result unless result[:status] == 'associated'

      result.merge(poster: @fetcher.call(record.reload))
    end

    private

    def remember(record, plan)
      poster = RecordPoster.create_or_find_by!(record_id: record.id)
      poster.with_lock do
        return { status: 'preserved', reason: 'Pochette protégée entre-temps' } if Fetch.preserved?(poster)
        return { status: 'changed', reason: 'Nouvelle référence de pochette à examiner' } if conflicting?(poster, plan)

        poster.update!(source: poster.source.merge(reference(plan)))
      end
      plan.merge(status: 'associated')
    end

    def conflicting?(poster, plan)
      ids = Evidence.new('collection').ids(poster.source).uniq
      ids.any? { |id| id != plan.fetch(:target) }
    end

    def reference(plan)
      { 'tmdb_collection_id' => plan.fetch(:target),
        'url' => "https://www.themoviedb.org/collection/#{plan.fetch(:target)}",
        'collection_inference' => { 'policy' => 'children_and_title_v1', 'movie_ids' => plan[:movies] || [],
                                    'observed_at' => Time.current.iso8601 } }
    end
  end
end
