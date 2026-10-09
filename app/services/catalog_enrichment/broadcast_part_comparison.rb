# frozen_string_literal: true

module CatalogEnrichment
  # Read-only proposals for a broadcaster's two-part edition of whole episodes.
  class BroadcastPartComparison
    def initialize(entries:, root:, directory:)
      @entries = entries.map(&:deep_symbolize_keys)
      @root = root
      @directory = Pathname.new(directory).cleanpath.to_s
    end

    def call
      scoped = @entries.select { |entry| entry.fetch(:path).start_with?("#{@directory}/") }
      parsed = scoped.filter_map { |entry| BroadcastPartName.call(entry) }
      groups = parsed.group_by { |part| [part[:season], normalized(part[:title]), normalized(part[:original])] }
      proposals = groups.map { |identity, parts| proposal(identity.first, parts) }
      result(scoped, parsed, proposals)
    end

    private

    def result(scoped, parsed, proposals)
      { format: 'vidb.broadcast_part_comparison', version: 1, read_only: true, root_record_id: @root.id,
        directory: @directory, file_count: scoped.size, part_groups: proposals.size,
        counts: proposals.group_by { |item| item[:status] }.transform_values(&:count),
        unparsed_paths: scoped.pluck(:path) - parsed.pluck(:path), proposals: proposals }
    end

    def proposal(season, parts)
      candidates = candidates_for(season, parts.first)
      numbered_parts = parts.group_by { |part| part[:part] }
      { season: season, title: parts.first[:title], original_title: parts.first[:original],
        status: status(numbered_parts, candidates), record_ids: candidates.map(&:id),
        multiple_copies: numbered_parts.any? { |_number, copies| copies.many? },
        title_differences: differences(candidates, parts.first), parts: parts }
    end

    def candidates_for(season, part)
      parents = @root.children.select { |record| record.rank == season }
      return [] unless parents.one?

      parents.first.children.select do |record|
        !record.has_children? && title_matches?(record, part)
      end
    end

    def title_matches?(record, part)
      normalized(record.french_title) == normalized(part[:title]) ||
        normalized(record.original_title) == normalized(part[:original])
    end

    def status(parts, candidates)
      return 'incomplete_pair' unless parts.keys.sort == [1, 2]
      return 'numbering_review' unless consistent_numbers?(parts)
      return 'identity_review' unless candidates.one?
      return 'catalogue_number_review' unless candidates.first.rank == (parts[1].first[:local_number] + 1) / 2

      'pair_proposal'
    end

    def consistent_numbers?(parts)
      first = parts[1].pluck(:local_number).uniq
      second = parts[2].pluck(:local_number).uniq
      first.one? && second.one? && first.first.odd? && second.first == first.first + 1
    end

    def differences(candidates, part)
      return [] unless candidates.one?

      record = candidates.first
      fields = { french_title: [record.french_title, part[:title]],
                 original_title: [record.original_title, part[:original]] }
      fields.filter_map { |field, values| difference(field, values) }
    end

    def difference(field, values)
      return if normalized(values.first) == normalized(values.last)

      { field: field, catalogue: values.first, file: values.last }
    end

    def normalized(title)
      BroadcastPartName.normalize(title)
    end
  end
end
