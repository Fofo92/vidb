module EncoderProjects
  # Expands an external double episode only when numbered local parts already exist.
  class LocalEpisodePartitions
    PART = /(?:\s*[-–—:]?\s*(?:part(?:ie)?\s*(\d+)|(\d+)(?:ère|ere|re|ème|eme|e|er)\s*partie)|\s*\((\d+)\))\s*\z/i

    def call(season, rows)
      offset = 0
      rows.sort_by { |row| row.fetch('episode_number') }.flat_map do |row|
        rank = row.fetch('episode_number') + offset
        parts = matching_parts(season, row, rank)
        mapped = parts.empty? ? [renumber(row, rank)] : expand(row, parts)
        offset += parts.size - 1 unless parts.empty?
        mapped
      end
    end

    private

    def renumber(row, rank)
      row.merge('episode_number' => rank,
                'external_episode_number' => row.fetch('external_episode_number', row.fetch('episode_number')))
    end

    def matching_parts(season, row, rank)
      return [] if row['external_parts'].present?
      return [] if marker(row['title_fr']) || marker(row['title_original'])

      candidates = season.children.where('rank >= ?', rank).order(:rank, :id).to_a
      parts = consecutive_parts(candidates, row, rank)
      return [] if parts.empty?
      raise ArgumentError, 'Parties locales incomplètes : correspondance à vérifier.' if parts.one?

      validate_duration!(row, parts)
      parts
    end

    def consecutive_parts(candidates, row, rank)
      expected = keys(row.values_at('title_fr', 'title_original'))
      parts = []
      candidates.each do |record|
        break unless record.rank == rank + parts.size && record.record_kind_episode?
        break unless marker(record.french_title) == parts.size + 1
        break unless expected.intersect?(keys([record.french_title]))

        parts << record
      end
      verify_complete_group!(parts, candidates, expected) if parts.any?
      parts
    end

    def verify_complete_group!(parts, candidates, expected)
      related = candidates.select do |record|
        marker(record.french_title) && expected.intersect?(keys([record.french_title]))
      end
      return if related.map(&:id) == parts.map(&:id)

      raise ArgumentError, 'Parties locales non consécutives ou dupliquées : correspondance à vérifier.'
    end

    def validate_duration!(row, parts)
      duration = row['reference_runtime_minutes']
      raise ArgumentError, 'Durée de l’épisode double insuffisante ou inconnue.' unless
        duration.is_a?(Numeric) && duration >= 18 * parts.size

      lengths = parts.map(&:length_in_mn)
      return unless lengths.all? { |value| value.is_a?(Numeric) && value.positive? }
      return if (lengths.sum - duration).abs <= [5, duration * 0.2].max

      raise ArgumentError, 'Les durées locales ne correspondent pas à l’épisode double.'
    end

    def expand(row, parts)
      parts.each_with_index.map do |record, index|
        row.merge('external_episode_number' => row.fetch('episode_number'), 'episode_number' => record.rank,
                  'title_fr' => record.french_title, 'title_original' => record.original_title,
                  'overview_fr' => nil, 'reference_runtime_minutes' => nil,
                  'local_partition' => { 'record_id' => record.id, 'part_number' => index + 1,
                                         'part_count' => parts.size, 'whole_title' => row['title_fr'],
                                         'whole_runtime_minutes' => row['reference_runtime_minutes'] })
      end
    end

    def marker(title)
      match = PART.match(title.to_s)
      return unless match

      match.captures.compact.first.to_i
    end

    def keys(titles)
      titles.compact_blank.map { |title| title.sub(PART, '').strip.parameterize }.reject(&:blank?)
    end
  end
end
