# frozen_string_literal: true

require "json"

module VideoAssetDataInventory
  module_function

  def run
    generated_at = Time.current
    output_path = output_path(generated_at)
    output_path.dirname.mkpath
    output_path.write(JSON.pretty_generate(report(generated_at)) << "\n")
    puts output_path
  end

  def report(generated_at)
    {
      generated_at: generated_at.iso8601,
      rails_environment: Rails.env,
      records: RecordInventory.report,
      language_versions: association_report,
      media: media_report
    }
  end

  def output_path(generated_at)
    Rails.root.join(
      "tmp",
      "video-asset-data-inventory-#{generated_at.to_date}.json"
    )
  end

  def association_report
    LanguageVersion.order(:id).map do |value|
      {
        id: value.id,
        short_name: value.short_name,
        long_name: value.long_name,
        record_count: Record.where(language_version_id: value.id).count
      }
    end
  end

  def media_report
    Medium.order(:id).map do |medium|
      {
        id: medium.id,
        short_name: medium.short_name,
        long_name: medium.long_name,
        record_count: medium.records.count
      }
    end
  end

  module RecordInventory
    module_function

    BOOLEAN_ATTRIBUTES = %w[is_recorded is_seen is_available is_checked].freeze
    def report
      structural_counts.merge(
        boolean_attributes: boolean_attributes,
        state_combinations: state_combinations,
        state_samples: StateSamples.report,
        length_in_mn: length_report,
        missing_associations: missing_associations
      )
    end

    def structural_counts
      branch_count = Record.find_each.count(&:has_children?)
      {
        total: Record.count,
        roots: Record.roots.count,
        branches: branch_count,
        leaves: Record.count - branch_count,
        by_kind: ordered_count(Record.group(:record_kind).count)
      }
    end

    def boolean_attributes
      BOOLEAN_ATTRIBUTES.to_h do |attribute|
        [attribute, boolean_distribution(attribute)]
      end
    end

    def boolean_distribution(attribute)
      counts = Record.group(attribute).count
      {
        "true" => counts.fetch(true, 0),
        "false" => counts.fetch(false, 0),
        null: counts.fetch(nil, 0)
      }
    end

    def missing_associations
      {
        language_version: Record.where(language_version_id: nil).count,
        medium: records_without_medium
      }
    end

    def records_without_medium
      Record.left_outer_joins(:media)
            .where(media: { id: nil })
            .distinct
            .count
    end

    def state_combinations
      Record.group(*BOOLEAN_ATTRIBUTES)
            .count
            .sort_by { |attributes, _count| attributes.map(&:to_s) }
            .map do |attributes, count|
        BOOLEAN_ATTRIBUTES.zip(attributes).to_h.merge(count: count)
      end
    end

    def length_report
      length_summary(Record.all).merge(by_kind: lengths_by_kind)
    end

    def lengths_by_kind
      Record.distinct.order(:record_kind).pluck(:record_kind).to_h do |kind|
        [kind || "null", length_summary(Record.where(record_kind: kind))]
      end
    end

    def length_summary(relation)
      values = relation.where.not(length_in_mn: nil)
      {
        populated: values.count,
        missing: relation.where(length_in_mn: nil).count,
        minimum: values.minimum(:length_in_mn),
        maximum: values.maximum(:length_in_mn),
        average: values.average(:length_in_mn)&.to_f&.round(2)
      }
    end

    def ordered_count(counts)
      counts.sort_by { |key, _count| key.to_s }.to_h
    end
  end

  module StateSamples
    module_function

    SAMPLE_SIZE = 10

    def report
      state_values.to_h do |values|
        relation = Record.where(RecordInventory::BOOLEAN_ATTRIBUTES.zip(values).to_h)
        [state_key(values), relation.order(:id).limit(SAMPLE_SIZE).map { |record| sample(record) }]
      end
    end

    def state_values
      Record.distinct.pluck(*RecordInventory::BOOLEAN_ATTRIBUTES)
            .sort_by { |values| values.map(&:to_s) }
    end

    def state_key(values)
      RecordInventory::BOOLEAN_ATTRIBUTES.zip(values)
                                         .map { |attribute, value| "#{attribute}=#{value}" }
                                         .join(";")
    end

    def sample(record)
      record.attributes.slice(
        "id", "french_title", "original_title", "record_kind",
        "ancestry", "rank", "length_in_mn"
      ).merge(has_children: record.has_children?)
    end
  end
end

VideoAssetDataInventory.run
