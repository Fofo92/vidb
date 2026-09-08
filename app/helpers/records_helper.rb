module RecordsHelper
  RECORD_KIND_LABELS = {
    "undetermined" => "À déterminer",
    "standalone_video" => "Vidéo autonome",
    "series" => "Série",
    "season" => "Saison",
    "episode" => "Épisode"
  }.freeze

  def record_kind_options
    Record.record_kinds.keys.map do |record_kind|
      [record_kind_label(record_kind), record_kind]
    end
  end

  def record_kind_label(record_kind)
    RECORD_KIND_LABELS.fetch(record_kind.to_s)
  end
end
