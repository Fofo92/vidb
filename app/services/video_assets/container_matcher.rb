# frozen_string_literal: true

module VideoAssets
  # Diagnoses directory title matches separately from episode identification.
  class ContainerMatcher
    COUNT_SUFFIX = /\s*\((?:[IVXLCDM\d\s_c-]|VF|VO|VOST|VM|VMST)+\)\s*\z/i

    def initialize(records)
      @by_id = records.index_by(&:id)
      @parent_ids = records.filter_map { |record| record.ancestry.to_s.split('/').last&.to_i }.uniq
      roots = records.select { |record| eligible?(record) }
      @roots = TitleMatcher.new(roots)
      @punctuation_index = punctuation_index(roots)
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

      candidates = punctuation_candidates(title)
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

    def punctuation_index(records)
      records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, index|
        [record.french_title, record.original_title, record.complete_title].compact_blank.each do |name|
          key = punctuation_key(name)
          index[key] << record.id if key.present? && !index[key].include?(record.id)
        end
      end
    end

    def punctuation_candidates(title)
      @punctuation_index.fetch(punctuation_key(title), []).map { |id| { record_id: id } }
    end

    def punctuation_key(value)
      value.to_s.unicode_normalize(:nfkc).downcase.gsub(/[[:punct:]]+/, ' ').squish
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
