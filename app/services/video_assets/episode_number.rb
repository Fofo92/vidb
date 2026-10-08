# frozen_string_literal: true

module VideoAssets
  # Reads explicit season/episode pairs without interpreting a catalogue index.
  class EpisodeNumber
    EXPLICIT = /(?<![[:alnum:]])S(?<season>\d+)\s*E(?<episode>\d+)\b/i
    DIRECT = /\A\s*(?:S(?<season>\d+)\s*)?(?:E|[ÉE]pisode\s+)(?<episode>\d+)\b/i

    def self.call(stem)
      matches = stem.to_enum(:scan, EXPLICIT).map { Regexp.last_match }
      return { reason: 'episode_number_ambiguous' } if matches.many?

      number = matches.first || DIRECT.match(stem)
      number ? { number: number } : { reason: 'episode_number_unrecognized' }
    end
  end
end
