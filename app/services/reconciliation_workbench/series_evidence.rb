require 'uri'

module ReconciliationWorkbench
  module SeriesEvidence
    IDENTITY = %w[id french_title original_title record_kind ancestry rank year].freeze

    def self.identity!(expected)
      record = Record.lock.find(expected.fetch('id'))
      return record if IDENTITY.all? { |key| expected.fetch(key) == record.public_send(key) }

      raise ArgumentError, "Identité ou structure de la fiche ##{record.id} modifiée depuis le dossier"
    end

    def self.source!(url)
      uri = URI.parse(url.to_s)
      return url if uri.scheme == 'https' && uri.host.present? && uri.userinfo.nil?

      raise ArgumentError, 'Source HTTPS requise'
    end

    def self.references(row)
      keys = SeriesTitles.keys(row.fetch('observed_title'))
      references = EpisodeSourcePolicy.preferred(row.fetch('reference_same_number') +
                                                  row.fetch('reference_other_numbers', []))
      references.select do |reference|
        reference.values_at('season', 'number') == row.values_at('local_season', 'local_episode') &&
          keys.include?(SeriesTitles.key(reference.fetch('name'))) &&
          !reference.fetch('name').match?(/\A(?:Episode|Épisode)\s*\d+\z/i)
      end
    end

    def self.file_matches?(row, directory)
      path = row.fetch('path')
      return false unless path.start_with?("#{directory}/") && !path.split('/').include?('..')

      match = File.basename(path).match(/\AS(\d+)\s*E(\d+)\s*[-–—]\s*(.+)\.(?:mkv|m4v|mp4|avi)\z/i)
      match && match.captures.first(2).map(&:to_i) == row.values_at('local_season', 'local_episode') &&
        SeriesTitles.keys(match[3]) == SeriesTitles.keys(row.fetch('observed_title'))
    end
  end
end
