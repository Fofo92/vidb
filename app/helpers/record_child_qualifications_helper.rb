module RecordChildQualificationsHelper
  CHILD_QUALIFICATION_LABELS = {
    "record_kind" => "Nature", "year" => "Année", "gender_ids" => "Genres", "country_ids" => "Pays",
    "language_version_id" => "Version de la fiche", "medium_ids" => "Supports de la fiche",
    "is_seen" => "Vu",
    "copy_language_version_id" => "Version des copies", "copy_medium_id" => "Support des copies"
  }.freeze

  def child_qualification_options(field)
    case field
    when "record_kind" then @qualification_targets.map { |kind| [record_kind_label(kind), kind] }
    when "gender_ids" then @genders
    when "country_ids" then @countries
    when "medium_ids", "copy_medium_id" then @media
    when "language_version_id", "copy_language_version_id" then @languages
    when "is_seen", "is_checked" then [["Oui", "yes"], ["Non", "no"], ["Inconnu", "unknown"]]
    else []
    end
  end

  def child_qualification_value(child, field)
    return nil unless child
    return child.public_send(field) if %w[record_kind year year_basis gender_ids country_ids medium_ids
                                          language_version_id].include?(field)
    return child_qualification_state(child, field) if %w[is_seen is_checked].include?(field)

    assets = VideoAsset.where(record_id: child.state_leaves.map(&:id), status: "present")
    attribute = field == "copy_medium_id" ? :medium_id : :language_version_id
    values = assets.distinct.pluck(attribute)
    values.one? ? values.first : nil
  end

  def child_qualification_state(child, field)
    value = if child.state_container?
              child_qualification_aggregate_state(child,
                                                  field)
            else
              child.effective_state(field.to_sym)
            end
    { true => "yes", false => "no", nil => "unknown" }.fetch(value)
  end

  def child_qualification_aggregate_state(child, field)
    counts = child.state_counts.fetch(field.to_sym)
    return nil unless counts[:total].positive?
    return true if counts[:yes] == counts[:total]
    return false if counts[:no] == counts[:total]

    nil
  end
end
