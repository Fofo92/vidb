# frozen_string_literal: true

module VideoAssets
  # Diagnoses directory title matches separately from episode identification.
  class ContainerMatcher
    COUNT_SUFFIX = /\s*\((?:[IVXLCDM\d\s_c-]|VF|VO|VOST|VM|VMST)+\)\s*\z/i

    def initialize(records)
      @by_id = records.index_by(&:id)
      @parent_ids = records.filter_map { |record| record.ancestry.to_s.split('/').last&.to_i }.uniq
      @roots = TitleMatcher.new(records.select { |record| eligible?(record) })
      @all = TitleMatcher.new(records)
      @cache = {}
    end

    def match(directory)
      @cache[directory] ||= resolve(directory)
    end

    private

    def eligible?(record)
      record.ancestry.blank? && @parent_ids.include?(record.id) &&
        %w[series undetermined].include?(record.record_kind)
    end

    def resolve(directory)
      title = directory.sub(COUNT_SUFFIX, '').strip
      candidates = title_candidates(@roots, directory, title)
      return resolved(candidates) if candidates.any?

      candidates = title_candidates(@all, directory, title)
      {
        roots: [], reason: candidates.empty? ? 'container_unmatched' : 'container_ineligible',
        container_candidates: candidates.map { |candidate| diagnostic(candidate) }
      }
    end

    def title_candidates(matcher, directory, title)
      exact = matcher.match(directory.strip)[:candidates]
      exact.any? ? exact : matcher.match(title)[:candidates]
    end

    def resolved(candidates)
      {
        roots: candidates.map { |candidate| @by_id.fetch(candidate[:record_id]) },
        reason: candidates.many? ? 'container_ambiguous' : nil,
        container_candidates: candidates
      }
    end

    def diagnostic(candidate)
      record = @by_id.fetch(candidate[:record_id])
      candidate.merge(
        non_root: record.ancestry.present?,
        has_children: @parent_ids.include?(record.id),
        supported_kind: %w[series undetermined].include?(record.record_kind)
      )
    end
  end
end
