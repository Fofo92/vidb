module ReconciliationWorkbench
  class CopyComparison
    DURATION_TOLERANCE_SECONDS = 2

    def call(samples)
      validate_samples!(samples)
      capabilities = samples.to_h { |sample| [sample.fetch('asset_id'), CopyCapabilities.new(sample).call] }
      result(capabilities)
    rescue ArgumentError, KeyError, TypeError => e
      { 'eligible' => false, 'reason' => e.message, 'quality_assessed' => false }
    end

    private

    def validate_samples!(samples)
      return if samples.size >= 2 && samples.map { |sample| sample.fetch('asset_id') }.uniq.size == samples.size

      raise ArgumentError, 'Au moins deux copies distinctes sont nécessaires'
    end

    def result(capabilities)
      winners = winner_ids(capabilities)
      common = { 'capabilities' => capabilities, 'quality_assessed' => false }
      unless winners.one?
        return common.merge('eligible' => false,
                            'reason' => 'Aucune copie ne remplit seule les critères ; examen nécessaire.')
      end

      common.merge('eligible' => true, 'preferred_asset_id' => winners.sole,
                   'reason' => 'Export video_encoder plus récent, plus riche en pistes et plus petit.')
    end

    def winner_ids(capabilities)
      selected = capabilities.select do |id, candidate|
        candidate['encoder_verified'] == true && capabilities.except(id).values.all? do |old|
          dominates?(candidate, old)
        end
      end
      selected.keys
    end

    def dominates?(candidate, old)
      Time.iso8601(candidate.fetch('modified_at')) > Time.iso8601(old.fetch('modified_at')) &&
        candidate.fetch('bytes').positive? && candidate.fetch('bytes') < old.fetch('bytes') &&
        duration_comparable?(candidate, old) && dimensions_preserved?(candidate, old) &&
        tracks_improved?(candidate, old)
    end

    def duration_comparable?(candidate, old)
      seconds = candidate.fetch('seconds')
      previous = old.fetch('seconds')
      seconds.positive? && previous.positive? && (seconds - previous).abs <= DURATION_TOLERANCE_SECONDS
    end

    def dimensions_preserved?(candidate, old)
      candidate.fetch('video').zip(old.fetch('video')).all? { |value, previous| value >= previous }
    end

    def tracks_improved?(candidate, old)
      preserved = %w[audio subtitles].all? { |kind| tracks_preserved?(candidate.fetch(kind), old.fetch(kind)) }
      richer = %w[audio subtitles].any? { |kind| (features(candidate, kind) - features(old, kind)).any? }
      preserved && richer && candidate.fetch('audio').any?
    end

    def features(copy, kind)
      useful = copy.fetch(kind).reject { |track| kind == 'audio' && track[1].include?('comment') }
      useful.map { |track| track.first(2) }
    end

    def tracks_preserved?(candidate, old)
      old.all? do |track|
        candidate.any? { |current| current.first(2) == track.first(2) && current.last >= track.last }
      end
    end
  end
end
