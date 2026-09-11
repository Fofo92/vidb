class RecordChildQualification
  include ActiveModel::Validations

  validate :validate_target_kind
  validate :validate_child_selection
  validate :validate_children_placements

  def initialize(parent:, child_ids:, record_kind:)
    @parent = parent
    @child_ids = child_ids
    @record_kind = record_kind
  end

  def call
    return false unless valid?

    qualify_children
    true
  rescue ActiveRecord::RecordInvalid => e
    add_record_invalid_error(e)
    false
  end

  private

  def qualify_children
    Record.transaction do
      selected_children.each { |child| child.update!(record_kind: @record_kind) }
    end
  end

  def add_record_invalid_error(exception)
    errors.add(
      :base,
      "Qualification annulée pour la fiche ##{exception.record.id} : " \
      "#{exception.record.errors.full_messages.to_sentence}"
    )
  end

  def validate_target_kind
    allowed_kinds =
      @parent.allowed_record_kinds_for_child_qualification

    return if allowed_kinds.include?(@record_kind)

    errors.add(
      :record_kind,
      "n’est pas autorisée pour les enfants de cette fiche"
    )
  end

  def validate_child_selection
    requested_ids = Array(@child_ids).map(&:to_s).uniq
    eligible_ids = selected_children.pluck(:id).map(&:to_s)

    return if requested_ids.any? &&
              requested_ids.sort == eligible_ids.sort

    errors.add(
      :child_ids,
      "doit contenir uniquement des enfants directs encore à déterminer"
    )
  end

  def validate_children_placements
    return if errors.any?

    selected_children.each do |child|
      next if children_compatible_with_target_kind?(child)

      errors.add(
        :child_ids,
        "contient la fiche « #{child.complete_title} » " \
        "dont les enfants sont incompatibles avec la nature choisie"
      )
    end
  end

  def children_compatible_with_target_kind?(record)
    record.children.all? do |child|
      Record.allowed_parent_kinds_for_hierarchy(child.record_kind)
            .include?(@record_kind)
    end
  end

  def selected_children
    @parent.children
           .where(id: @child_ids, record_kind: "undetermined")
           .order(:id)
  end
end
