class RecordStateUpdate
  FIELDS = %w[is_seen is_checked].freeze
  VALUES = { "yes" => true, "no" => false, "unknown" => nil }.freeze

  def initialize(parent:, field:, value:, child_id: nil)
    @parent = parent
    @field = field.to_s
    @value = value.to_s
    @child_id = child_id.presence
  end

  def call
    validate_choice!
    @parent.with_lock do
      ids = targets.map(&:id).uniq
      records = Record.where(id: ids).order(:id).lock.to_a
      records.each { |record| record.update!(attributes) }
      records.length
    end
  end

  private

  def validate_choice!
    raise ArgumentError, "Propriété non modifiable ici." unless FIELDS.include?(@field)
    raise ArgumentError, "Valeur invalide." unless VALUES.key?(@value)
  end

  def targets
    children = @parent.children.to_a
    return children.flat_map(&:state_leaves) unless @child_id

    child = children.find { |record| record.id.to_s == @child_id.to_s }
    raise ArgumentError, "Cette fiche ne figure pas dans le tableau." unless child
    raise ArgumentError, "Les états de cette fiche sont calculés." if child.state_container?

    [child]
  end

  def attributes
    result = { @field => VALUES.fetch(@value) }
    return result unless @field == "is_seen"

    result.merge(seen_state_confirmed_at: @value == "unknown" ? nil : Time.current)
  end
end
