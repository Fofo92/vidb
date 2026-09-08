module RecordsHelper
  RECORD_KIND_LABELS = {
    "undetermined" => "À déterminer",
    "standalone_video" => "Vidéo autonome",
    "series" => "Série",
    "season" => "Saison",
    "episode" => "Épisode"
  }.freeze

  HIERARCHY_PLACEMENT_PRESENTATIONS = {
    consistent: {
      label: "Conforme",
      badge_class: "text-bg-success"
    },
    undetermined: {
      label: "À déterminer",
      badge_class: "text-bg-warning"
    },
    inconsistent: {
      label: "Incohérent",
      badge_class: "text-bg-danger"
    }
  }.freeze

  def record_kind_options
    Record.record_kinds.keys.map do |record_kind|
      [record_kind_label(record_kind), record_kind]
    end
  end

  def record_kind_label(record_kind)
    RECORD_KIND_LABELS.fetch(record_kind.to_s)
  end

  def hierarchy_placement_label(status)
    hierarchy_placement_presentation(status).fetch(:label)
  end

  def hierarchy_placement_badge_class(status)
    hierarchy_placement_presentation(status).fetch(:badge_class)
  end

  private

  def hierarchy_placement_presentation(status)
    HIERARCHY_PLACEMENT_PRESENTATIONS.fetch(status.to_sym)
  end
end
