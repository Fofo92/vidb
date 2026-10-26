module EncoderProjects
  class EpisodeEditionMapping
    def call(rows, local_entries)
      return rows if local_entries.empty?

      @split_edition = rows.size > local_entries.size
      validate_numbers!(rows)
      groups = rows.sort_by { |row| row.fetch('episode_number') }.chunk { |row| group_key(row) }.map(&:last)
      matches = local_entries.map { |number, item| match_group(number, item, groups) }
      validate_coverage!(rows, matches)
      matches
    end

    def from_parts(number, title, source, parts)
      parts = parts.sort_by { |row| row.fetch('episode_number') }
      validate_parts!(parts, local_title: title)
      grouped_row(number, { 'title' => title, 'source' => source }, parts)
    end

    private

    def validate_numbers!(rows)
      numbers = rows.pluck('episode_number').sort
      return if numbers.empty? || numbers == (numbers.first..numbers.last).to_a

      raise ArgumentError, 'Numéros externes manquants ou répétés : découpage à vérifier.'
    end

    def validate_coverage!(rows, matches)
      used = matches.flat_map { |row| row.fetch('external_parts').pluck('episode_id') }
      return if used.uniq.size == used.size && used.sort == rows.pluck('tmdb_episode_id').sort

      raise ArgumentError, 'Découpage à consolider : certaines parties sont absentes ou utilisées plusieurs fois.'
    end

    def group_key(row)
      EpisodeEditionTitles.keys([row['title_fr'].presence || row['title_original']]).first
    end

    def match_group(number, item, groups)
      keys = EpisodeEditionTitles.keys(item.values_at('title', 'original_title'))
      matches = groups.select do |parts|
        keys.intersect?(EpisodeEditionTitles.keys(parts.first.values_at('title_fr', 'title_original')))
      end
      raise ArgumentError, "Découpage à consolider pour l’épisode local #{number}." unless matches.one?

      parts = matches.sole
      marker = EpisodeEditionTitles.part(item['title'])
      parts = select_part(parts, marker) if marker
      validate_parts!(parts, local_title: item['title'])
      grouped_row(number, item, parts)
    end

    def select_part(parts, marker)
      parts.each_with_index.filter_map do |row, index|
        row if (part_number(row) || (index.zero? ? 1 : nil)) == marker
      end
    end

    def part_number(row)
      EpisodeEditionTitles.part(row['title_fr']) || EpisodeEditionTitles.part(row['title_original'])
    end

    def validate_parts!(parts, local_title:)
      return validate_single!(parts.first, local_title) if parts.one?

      markers = parts.map { |row| part_number(row) }
      markers[0] ||= 1
      numbers = parts.pluck('episode_number')
      valid = parts.any? && markers == (1..parts.size).to_a && numbers == (numbers.first..numbers.last).to_a
      raise ArgumentError, 'Parties incomplètes ou non consécutives : aucune association automatique.' unless valid
    end

    def validate_single!(row, local_title)
      return if EpisodeEditionTitles.part(local_title)

      duration = row['reference_runtime_minutes']
      complete = !@split_edition || (duration.is_a?(Numeric) && duration >= 60)
      return if part_number(row).nil? && complete

      raise ArgumentError, 'Une seule partie est disponible pour un épisode entier : correspondance à vérifier.'
    end

    def grouped_row(number, item, parts)
      first = parts.first
      first.merge('episode_number' => number, 'external_episode_number' => first.fetch('episode_number'),
                  'title_fr' => item.fetch('title'),
                  'title_original' => EpisodeEditionTitles.base(first['title_original']),
                  'title_aliases' => parts.flat_map { |row| row.values_at('title_fr', 'title_original') },
                  'overview_fr' => parts.pluck('overview_fr').compact_blank.uniq.join("\n\n"),
                  'reference_runtime_minutes' => reference_duration(parts),
                  'numbering_source' => item.fetch('source'), 'external_parts' => part_evidence(parts))
    end

    def reference_duration(parts)
      values = parts.pluck('reference_runtime_minutes')
      values.sum if values.all? { |value| value.is_a?(Numeric) && value.positive? }
    end

    def part_evidence(parts)
      parts.map do |row|
        { 'episode_id' => row.fetch('tmdb_episode_id'), 'episode_number' => row.fetch('episode_number'),
          'title' => row['title_fr'], 'original_title' => row['title_original'],
          'runtime_minutes' => row['reference_runtime_minutes'] }
      end
    end
  end
end
