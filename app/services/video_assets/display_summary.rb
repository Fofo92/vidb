# frozen_string_literal: true

module VideoAssets
  class DisplaySummary
    def initialize(record:, records:, assets:)
      @record = record
      parents = records.filter_map(&:parent_id)
      @leaves = records.reject { |node| parents.include?(node.id) }
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
      label
    end

    def supports
      qualifications(:medium, @record.media.map(&:short_name), 'Support catalogue')
    end

    def languages
      qualifications(:language_version, [@record.language_version&.short_name].compact, 'Version catalogue')
    end

    private

    def measured_duration_label(ranges)
      minimum = ranges.sum(&:min)
      maximum = ranges.sum(&:max)
      lower = self.class.format_minutes(minimum)
      upper = self.class.format_minutes(maximum)
      minimum == maximum ? lower : "#{lower}–#{upper} selon les copies"
    end

    def duration_ranges
      leaves = @leaves.index_by(&:id)
      @assets.group_by(&:record_id).filter_map do |id, copies|
        PartDuration.range(copies, expected_parts: leaves.fetch(id).broadcast_part_count)
      end
    end

    def catalogue_duration
      duration = @record.formatted_total_length
      duration == '00h00' ? 'Durée inconnue' : "#{duration} (catalogue)"
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
