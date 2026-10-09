# frozen_string_literal: true

module CatalogEnrichment
  class EncodingPilotTitles
    SUFFIX = /\s+\([1-9]\d*\)\z/

    def initialize(overrides:)
      @overrides = overrides.deep_stringify_keys
    end

    def call(entry)
      entry = entry.deep_stringify_keys
      override = @overrides[entry.fetch('tmdb_episode_id').to_s]
      return entry unless override

      validate!(entry, override)
      entry.merge('catalogue_title_fr' => override.fetch('title_fr'),
                  'catalogue_title_original' => override.fetch('title_original'),
                  'title_decision' => { 'basis' => 'Pascal confirmed removal of narrative arc suffixes on 2026-10-09',
                                        'tmdb_title_fr' => entry.fetch('catalogue_title_fr'),
                                        'tmdb_title_original' => entry.fetch('title_original') })
    end

    private

    def validate!(entry, override)
      valid = entry.fetch('catalogue_title_fr').sub(SUFFIX, '') == override.fetch('title_fr') &&
              entry.fetch('title_original').sub(SUFFIX, '') == override.fetch('title_original')
      raise ArgumentError, 'External titles changed; local title decision requires review' unless valid
    end
  end
end
