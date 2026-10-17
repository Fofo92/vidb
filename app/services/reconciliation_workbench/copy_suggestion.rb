module ReconciliationWorkbench
  # An advisory choice by measurable advantages, never permission to apply.
  class CopySuggestion
    def self.call(payload)
      return payload.dig('comparison', 'preferred_asset_id') if payload.dig('comparison', 'eligible')

      samples = payload.fetch('samples', [])
      return unless samples.size >= 2

      winners = samples.select do |candidate|
        samples.excluding(candidate).all? { |old| new.dominates?(candidate, old) }
      end
      winners.sole['asset_id'] if winners.one?
    rescue ArgumentError, KeyError, TypeError
      nil
    end

    def dominates?(candidate, old)
      current = candidate.fetch('measurement')
      previous = old.fetch('measurement')
      Time.iso8601(candidate.fetch('modified_at')) > Time.iso8601(old.fetch('modified_at')) &&
        current.fetch('byte_size').positive? && current.fetch('byte_size') < previous.fetch('byte_size') &&
        current.fetch('measured_duration_seconds').positive? && previous.fetch('measured_duration_seconds').positive? &&
        (current.fetch('measured_duration_seconds') - previous.fetch('measured_duration_seconds')).abs <= 2 &&
        tracks_improved?(current, previous) && video_preserved?(current, previous)
    end

    private

    def streams(measured, type)
      measured.fetch('technical_details').fetch('streams').select { |stream| stream['codec_type'] == type }
    end

    def tracks_improved?(current, previous)
      counts = %w[audio subtitle].map { |type| [streams(current, type).size, streams(previous, type).size] }
      counts.first.first.positive? && counts.all? { |now, old| now >= old } && counts.any? { |now, old| now > old }
    end

    def positive_sizes?(sizes)
      sizes.flatten.all? { |value| value.is_a?(Numeric) && value.positive? }
    end

    def video_preserved?(current, previous)
      videos = [current, previous].map { |measured| streams(measured, 'video') }
      return false unless videos.all?(&:one?)

      sizes = videos.map { |list| list.sole.values_at('width', 'height') }
      positive_sizes?(sizes) &&
        sizes.first.zip(sizes.last).all? { |now, old| now >= old }
    end
  end
end
