# frozen_string_literal: true

module VideoAssets
  class DisplaySummary
    def initialize(record:, records:, assets:)
      @record = record
      parents = records.filter_map(&:parent_id)
      @leaves = records.reject { |node| parents.include?(node.id) || node.metadata_container? }
      leaf_ids = @leaves.map(&:id)
      @assets = assets.select { |asset| leaf_ids.include?(asset.record_id) }
    end

    def self.format_minutes(minutes)
      return "#{minutes} mn" if minutes < 60

      format('%<hours>02d:%<minutes>02d', hours: minutes / 60, minutes: minutes % 60)
    end

    def duration
      return catalogue_duration if @assets.empty?

      ranges = duration_ranges
      return 'Durée mesurée inconnue' if ranges.empty?

      label = measured_duration_label(ranges)
      label += " — partiel : #{ranges.size}/#{@leaves.size}" if ranges.size < @leaves.size
      label += ' — certaines copies non mesurées' if @assets.any? { |asset| asset.duration_minutes.nil? }
      label += ' — durées de fiches incluses' if catalogue_ranges?
      label
    end

    def supports
      qualifications(:medium, fallback_values(:medium).map(&:short_name), 'Support catalogue')
    end

    def languages
      qualifications(:language_version, fallback_values(:language_version).map(&:short_name), 'Version catalogue')
    end

    def summary_duration
      if @assets.empty?
        value = @record.formatted_total_length
        return ['00h00', 'Inconnue'].include?(value) ? '—' : value
      end

      ranges = duration_ranges
      return '—' if ranges.empty?

      label = measured_duration_label(ranges).delete_suffix(' selon les copies')
      ranges.size < @leaves.size ? "≥ #{label}" : label
    end

    def summary_supports
      summary_names(:medium)
    end

    def summary_languages
      summary_names(:language_version)
    end

    private

    def summary_names(association)
      copies = @assets.group_by(&:record_id)
      values = @leaves.flat_map do |leaf|
        present = copies.fetch(leaf.id, [])
        present.empty? ? leaf_values(leaf, association) : present.filter_map { |asset| asset.public_send(association) }
      end
      names = values.map(&:short_name).select { |name| RecordMetadataValues.known?(name) }
      names.uniq.sort.join(', ').presence || '—'
    end

    def measured_duration_label(ranges)
      minimum = ranges.sum(&:min)
      maximum = ranges.sum(&:max)
      lower = self.class.format_minutes(minimum)
      upper = self.class.format_minutes(maximum)
      minimum == maximum ? lower : "#{lower}–#{upper} selon les copies"
    end

    def duration_ranges
      copies = @assets.group_by(&:record_id)
      @leaves.filter_map do |leaf|
        measured = PartDuration.range(copies.fetch(leaf.id, []), expected_parts: leaf.broadcast_part_count)
        measured || ([leaf.length_in_mn, leaf.length_in_mn] if leaf.length_in_mn&.positive?)
      end
    end

    def catalogue_ranges?
      copies = @assets.group_by(&:record_id)
      @leaves.any? do |leaf|
        leaf.length_in_mn&.positive? &&
          PartDuration.range(copies.fetch(leaf.id, []), expected_parts: leaf.broadcast_part_count).nil?
      end
    end

    def fallback_values(association)
      @leaves.flat_map { |leaf| leaf_values(leaf, association) }.uniq(&:id)
    end

    def leaf_values(leaf, association)
      association == :medium ? leaf.media.to_a : [leaf.language_version].compact
    end

    def catalogue_duration
      duration = @record.formatted_total_length
      ['00h00', 'Inconnue'].include?(duration) ? 'Durée inconnue' : "#{duration} (catalogue)"
    end

    def qualifications(association, fallback, label)
      return catalogue_qualification(fallback, label) if @assets.empty?

      names = @assets.filter_map { |asset| asset.public_send(association)&.short_name }.uniq.sort
      unknown = @assets.any? { |asset| asset.public_send(association).nil? }
      names << 'non renseigné' if unknown
      names << "couverture #{@assets.map(&:record_id).uniq.size}/#{@leaves.size}" if incomplete?
      names.join(', ')
    end

    def catalogue_qualification(values, label)
      return 'Non renseigné' if values.empty?

      "#{values.join(', ')} (#{label.downcase})"
    end

    def incomplete?
      @assets.map(&:record_id).uniq.size < @leaves.size
    end
  end
end
