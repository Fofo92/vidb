module Tv
  class LibraryEpisodeAcquisitions
    def initialize(candidates: LibraryEpisodeCandidates.new)
      @candidates = candidates
    end

    def call(programmes)
      @candidates.call(programmes).transform_values { |record| evidence(record) }.compact
    end

    EVIDENCE = {
      'available' => ['Déjà acquis — disponible', 'Une copie complète est présente dans la vidéothèque vidb.'],
      'history' => ['Déjà acquis — indisponible',
                    'L’acquisition est conservée dans vidb, mais aucune copie complète n’est actuellement disponible.'],
      'recorded' => ['Déjà enregistré — catalogue',
                     'La fiche vidb est marquée enregistrée ; la disponibilité du fichier reste à vérifier.']
    }.freeze

    private

    def evidence(record)
      kind = acquisition_kind(record, record.video_assets.to_a)
      return unless kind

      label, description = EVIDENCE.fetch(kind)
      EpisodeAcquisition.new(kind: kind, label: label, description: description, record_id: record.id, paths: [])
    end

    def acquisition_kind(record, assets)
      return 'available' if VideoAssets::PartCoverage.available?(assets, expected_parts: record.broadcast_part_count)
      return 'history' if VideoAssets::PartCoverage.recorded?(assets, expected_parts: record.broadcast_part_count)
      return 'recorded' if assets.empty? && record.is_recorded == true

      nil
    end
  end
end
