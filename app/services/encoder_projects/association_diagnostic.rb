module EncoderProjects
  # Explain the current Matcher checks without changing qualification or stored proposals.
  class AssociationDiagnostic
    Issue = Data.define(:record, :message, :action)
    LABELS = { 'undetermined' => 'À déterminer', 'standalone_video' => 'Vidéo autonome',
               'collection' => 'Collection de films', 'series' => 'Série',
               'season' => 'Saison', 'episode' => 'Épisode' }.freeze

    def self.call(record)
      new(record).call
    end

    def initialize(record)
      @record = record
    end

    def call
      return if Matcher.qualified?(@record)

      intrinsic_issue || placement_issue || role_issue
    end

    private

    def issue(record, message, action = :edit)
      Issue.new(record: record, message: message, action: action)
    end

    def intrinsic_issue
      return issue(nil, 'La fiche proposée n’existe plus.', :none) unless @record
      if @record.has_children?
        return issue(@record, 'Cette fiche contient des enfants : choisis la fiche de l’œuvre à encoder.', :show)
      end
      return unless @record.record_kind_undetermined?

      issue(@record, 'Nature non renseignée : précise « Vidéo autonome » ou « Épisode » selon l’œuvre.')
    end

    def placement_issue
      return issue(@record, "Parent n° #{@record.parent_id} introuvable.", :placement) if missing_parent?

      parent = @record.parent
      if parent&.record_kind_undetermined?
        return issue(parent, 'La nature de cette fiche parent est « À déterminer » : précise sa nature.')
      end
      return if Matcher.valid_placement?(@record)

      context = parent ? "parent n° #{parent.id} de nature « #{LABELS.fetch(parent.record_kind)} »" : 'aucun parent'
      issue(@record, "Placement incompatible : nature « #{LABELS.fetch(@record.record_kind)} », #{context}.",
            :placement)
    end

    def missing_parent?
      @record.has_parent? && @record.parent.nil?
    end

    def role_issue
      return episode_issue if @record.record_kind_episode?

      issue(@record, "Nature « #{LABELS.fetch(@record.record_kind)} » : cette fiche représente un ensemble. " \
                     'Choisis une vidéo autonome ou un épisode.', :show)
    end

    def episode_issue
      season = @record.parent
      unless season&.record_kind_season?
        return issue(@record, 'Cet épisode doit être rattaché à une saison, elle-même rattachée à une série.',
                     :placement)
      end

      issue(season, 'Cette saison doit être rattachée à une fiche de nature « Série ».', :placement)
    end
  end
end
