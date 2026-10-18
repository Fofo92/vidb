module ReconciliationWorkbench
  module SeriesEpisodeFile
    def self.matches?(row, directory, prefixes:)
      path = row.fetch('path')
      return false unless path.start_with?("#{directory}/") && !path.split('/').include?('..')
      return false unless File.extname(path).match?(/\A\.(?:mkv|m4v|mp4|avi)\z/i)

      stem = File.basename(path, File.extname(path))
      number = VideoAssets::EpisodeNumber.call(stem)[:number]
      number && valid_number?(number, row) && prefix?(stem[...number.begin(0)], prefixes) &&
        title?(stem[number.end(0)..], row.fetch('observed_title'))
    end

    def self.valid_number?(number, row)
      number.names.include?('season') && number[:season].present? &&
        [number[:season].to_i, number[:episode].to_i] == row.values_at('local_season', 'local_episode')
    end

    def self.prefix?(value, names)
      prefix = SeriesTitles.key(value)
      return true if prefix.empty?

      allowed = names.compact_blank.flat_map do |name|
        [SeriesTitles.key(name), SeriesTitles.key(name.scan(/\p{Alnum}+/).map { |word| word[0] }.join)]
      end
      allowed.include?(prefix)
    end

    def self.title?(tail, observed_title)
      match = tail.match(/\A\s*[-–—]\s*(.+)\z/)
      match && SeriesTitles.keys(match[1]) == SeriesTitles.keys(observed_title)
    end
  end
end
