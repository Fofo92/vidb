# frozen_string_literal: true

module VideoAssets
  # Proposes title candidates without accepting an identification.
  class TitleMatcher
    LANGUAGE_SUFFIX = /(?:\s*\((?:VF|VO|VOST|VM|VMST)\)|_vf)+\z/i

    def initialize(records)
      @records = records.to_a
      @index = build_index
    end

    def match(stem)
      exact_key = normalize(stem)
      exact = candidates(exact_key)
      return result('exact', exact) if exact.any?

      convention_key = normalize(strip_language_suffix(stem))
      convention = candidates(convention_key)
      return result('convention', convention) if convention.any?

      result('unmatched', [])
    end

    private

    attr_reader :records, :index

    def build_index
      records.each_with_object(Hash.new { |hash, key| hash[key] = [] }) do |record, result|
        title_variants(record).each { |title| result[normalize(title)] << record }
      end
    end

    def title_variants(record)
      [record.french_title, record.original_title, record.complete_title]
        .compact_blank
        .uniq
    end

    def normalize(value)
      value.to_s.unicode_normalize(:nfkc).downcase.gsub(/\s+/, ' ').strip
    end

    def strip_language_suffix(value)
      value.to_s.sub(LANGUAGE_SUFFIX, '').strip
    end

    def candidates(key)
      return [] if key.empty?

      index.fetch(key, []).uniq(&:id)
    end

    def result(kind, records)
      status = records.many? ? "ambiguous_#{kind}" : kind
      {
        status: status,
        candidates: records.map { |record| candidate(record) }
      }
    end

    def candidate(record)
      {
        record_id: record.id,
        french_title: record.french_title,
        original_title: record.original_title,
        record_kind: record.record_kind,
        ancestry: record.ancestry,
        rank: record.rank
      }
    end
  end
end
