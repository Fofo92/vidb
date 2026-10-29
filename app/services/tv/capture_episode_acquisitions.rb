module Tv
  class CaptureEpisodeAcquisitions
    def initialize(index: CaptureEpisodeIndex.new)
      @index = index
    end

    def call(programmes)
      return {} if programmes.empty?

      by_episode = @index.call.group_by { |entry| entry.fetch(:key) }
      programmes.to_h do |programme|
        rows = by_episode.fetch(AcquiredEpisodeIdentity.key(programme), []).select do |entry|
          AcquiredEpisodeIdentity.concordant?(programme, [entry.fetch(:title)])
        end
        [programme.id, evidence(rows)]
      end.compact
    end

    private

    def evidence(rows)
      return if rows.empty?

      kind = rows.any? { |row| row[:kind] == 'capture' } ? 'capture' : 'quarantine'
      label = kind == 'capture' ? 'Capture présente — à vérifier' : 'Source en quarantaine'
      paths = rows.map { |row| row.fetch(:path) }.uniq.sort
      description = 'Source trouvée ; cela ne garantit ni la fin de la capture ni un encodage complet. '
      EpisodeAcquisition.new(kind: kind, label: label, description: description + paths.join(' ; '), paths: paths)
    end
  end
end
