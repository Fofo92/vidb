module Tv
  class LibraryEpisodeAcquisitions
    def initialize(candidates: LibraryAcquisitionCandidates.new, projects: VideoEncoderProjectEvidence.new)
      @candidates = candidates
      @projects = projects
    end

    def call(programmes)
      @candidates.call(programmes).transform_values { |record| evidence(record) }.compact
    end

    EVIDENCE = {
      'replace_copy' => ['À reprogrammer — copie à remplacer',
                         'Les copies connues sont incomplètes ou sévèrement dégradées.'],
      'copy_review' => ['Qualité de la copie à vérifier',
                        'La couverture disponible dépend d’une copie légèrement dégradée.'],
      'available' => ['Déjà encodé avec video_encoder',
                      'Une copie complète disponible possède un projet video_encoder associé.'],
      'reencode' => ['Réencodage souhaité — ancienne copie',
                     'Une copie complète est disponible, mais aucun projet video_encoder associé n’a été trouvé.'],
      'project_review' => ['Copie disponible — projet à vérifier',
                           'Le projet associé est illisible ou sa liaison est contradictoire ; ' \
                           'vérifie avant de conclure.'],
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

    def available_kind(record, assets)
      states = assets.select(&:status_present?).map { |asset| [asset, @projects.call(asset)] }
      associated = project_copies(states, [:associated])
      return 'available' if complete?(associated, record)

      possible = project_copies(states, %i[associated unknown])
      return 'project_review' if complete?(possible, record)

      'reencode'
    end

    def project_copies(states, allowed)
      states.filter_map { |asset, state| asset if allowed.include?(state) }
    end

    def complete?(assets, record)
      VideoAssets::PartCoverage.available?(assets, expected_parts: record.broadcast_part_count)
    end

    def acquisition_kind(record, assets)
      kind = copy_condition_kind(record, assets)
      return kind if kind
      return 'history' if VideoAssets::PartCoverage.recorded?(assets, expected_parts: record.broadcast_part_count)
      return 'recorded' if assets.empty? && record.is_recorded == true

      nil
    end

    def copy_condition_kind(record, assets)
      usable = assets.reject { |asset| defective?(asset) }
      preferred = usable.reject { |asset| asset.effective_condition['damage'] == 'light' }
      return available_kind(record, preferred) if complete?(preferred, record)
      return 'copy_review' if complete?(usable, record)

      'replace_copy' if usable.size < assets.size
    end

    def defective?(asset)
      condition = asset.effective_condition
      condition['integrality'] == 'incomplete' || condition['damage'] == 'severe'
    end
  end
end
