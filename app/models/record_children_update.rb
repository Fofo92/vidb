class RecordChildrenUpdate
  include ActiveModel::Validations

  attr_reader :child_ids, :changed_count

  def initialize(parent:, child_ids:, common:, rows:, snapshots:)
    @parent = parent
    @child_ids = Array(child_ids).reject(&:blank?).map(&:to_s).uniq
    @common = common
    @rows = rows.to_h.stringify_keys
    @snapshots = snapshots.fetch(:children).to_h.stringify_keys
    @parent_snapshot = snapshots[:parent]
    @changed_count = 0
  end

  def call
    Record.transaction { apply_changes? }
  rescue ArgumentError, ActiveRecord::RecordInvalid => e
    errors.add(:base, e.message)
    false
  rescue ActiveRecord::Deadlocked, ActiveRecord::LockWaitTimeout
    errors.add(:base, "Une autre modification est en cours. Recharge la page et réessaie.")
    false
  end

  private

  def apply_changes?
    lock_tables
    @parent.reload
    children = @parent.children.where(id: @child_ids).order(:id).to_a
    validate_selection!(children)
    validate_snapshots!(children)
    plans = build_plans(children)
    plans.each { |child, values| apply_child(child, values) }
    @changed_count = plans.length
    true
  end

  def apply_child(child, values)
    RecordChildChanges.new(record: child, values: values, parent: @parent).call
  end

  def build_plans(children)
    common = RecordChildChanges.values(@common)
    children.map do |child|
      values = common.merge(RecordChildChanges.values(@rows.fetch(child.id.to_s, {})))
      raise ArgumentError, "Choisis au moins un champ à appliquer." if values.empty?

      [child, values]
    end
  end

  def lock_tables
    Record.connection.execute(
      "LOCK TABLE records, video_assets, countries_records, genders_records, media_records " \
      "IN SHARE ROW EXCLUSIVE MODE"
    )
  end

  def validate_selection!(children)
    return if @child_ids.any? && children.map { |child| child.id.to_s }.sort == @child_ids.sort

    raise ArgumentError, "Sélectionne uniquement des enfants directs de cette fiche."
  end

  def validate_snapshots!(children)
    unless RecordChildQualificationSnapshot.matches?(@parent, @parent_snapshot)
      raise ArgumentError, "Les données ont changé. Recharge la page avant de qualifier les enfants."
    end

    children.each do |child|
      next if RecordChildQualificationSnapshot.matches?(child, @snapshots[child.id.to_s])

      raise ArgumentError, "La fiche « #{child.complete_title} » a changé. Recharge la page."
    end
  end
end
