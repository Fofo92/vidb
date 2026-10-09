class RecordChildChanges
  ASSOCIATIONS = { "gender_ids" => Gender, "country_ids" => Country, "medium_ids" => Medium }.freeze
  STATES = { "yes" => true, "no" => false, "unknown" => nil }.freeze
  FIELDS = %w[record_kind year gender_ids country_ids medium_ids language_version_id
              is_seen is_checked copy_language_version_id copy_medium_id].freeze

  def self.values(parameters)
    parameters = parameters.to_h.stringify_keys
    fields = Array(parameters["fields"]).reject(&:blank?).uniq
    raise ArgumentError, "Champ inconnu." unless (fields - FIELDS).empty?

    result = parameters.slice(*fields)
    result["year_basis"] = parameters.fetch("year_basis", "unknown") if fields.include?("year")
    raise ArgumentError, "Valeur manquante." unless (fields - result.keys).empty?

    result
  end

  def initialize(record:, values:, parent:)
    @record = record
    @values = values
    @parent = parent
  end

  def call
    validate_kind!
    @record.update!(record_attributes)
    update_states
    RecordChildrenCopyUpdate.new(record: @record, attributes: copy_attributes).call
  end

  private

  def validate_kind!
    kind = @values["record_kind"]
    return unless kind

    valid = @parent.allowed_record_kinds_for_child_qualification.include?(kind)
    valid &&= @record.children.all? do |child|
      Record.allowed_parent_kinds_for_hierarchy(child.record_kind).include?(kind)
    end
    raise ArgumentError, "Nature incompatible pour « #{@record.complete_title} »." unless valid
  end

  def record_attributes
    result = @values.slice("record_kind")
    ASSOCIATIONS.each do |field, model|
      result[field] = association_ids(model, @values[field]) if @values.key?(field)
    end
    if @values.key?("language_version_id")
      result["language_version_id"] = reference_id(LanguageVersion, @values["language_version_id"])
    end
    result.merge!(year_attributes) if @values.key?("year")
    result
  end

  def year_attributes
    year = parsed_year
    basis = year ? @values.fetch("year_basis") : "unknown"
    raise ArgumentError, "Origine de l’année invalide." unless %w[unknown first_release production].include?(basis)
    return {} if @record.year == year && @record.year_basis == basis

    { year: year, year_basis: basis, year_evidence: year_evidence(year) }
  end

  def year_evidence(year)
    return {} unless year

    { "source" => "Qualification manuelle", "parent_record_id" => @parent.id, "year" => year }
  end

  def parsed_year
    value = @values["year"].presence
    raise ArgumentError, "Année invalide." if value && !/\A\d{4}\z/.match?(value.to_s)

    value&.to_i
  end

  def association_ids(model, values)
    ids = Array(values).reject(&:blank?).map { |value| integer_id(value) }.uniq
    raise ArgumentError, "Deux genres principaux au maximum." if model == Gender && ids.size > 2
    raise ArgumentError, "Référence inconnue." unless model.where(id: ids).count == ids.length

    ids
  end

  def reference_id(model, value)
    id = integer_id(value)
    raise ArgumentError, "Référence inconnue." unless model.exists?(id)

    id
  end

  def integer_id(value)
    raise ArgumentError, "Référence invalide." unless /\A[1-9]\d*\z/.match?(value.to_s)

    value.to_i
  end

  def update_states
    values = @values.slice("is_seen", "is_checked")
    return if values.empty?

    attributes = values.transform_values do |value|
      raise ArgumentError, "État invalide." unless STATES.key?(value)

      STATES.fetch(value)
    end
    if values.key?("is_seen")
      attributes["seen_state_confirmed_at"] = values["is_seen"] == "unknown" ? nil : Time.current
    end
    @record.state_leaves.each { |leaf| leaf.update!(attributes) }
  end

  def copy_attributes
    result = {}
    if @values.key?("copy_language_version_id")
      result[:language_version_id] = reference_id(LanguageVersion, @values["copy_language_version_id"])
    end
    result[:medium_id] = reference_id(Medium, @values["copy_medium_id"]) if @values.key?("copy_medium_id")
    result
  end
end
