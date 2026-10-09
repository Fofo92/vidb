# frozen_string_literal: true

module RecordYears
  extend ActiveSupport::Concern

  LABELS = { 'unknown' => '?', 'first_release' => 'Diff.', 'production' => 'Prod.', 'mixed' => 'Mixte' }.freeze

  included do
    validates :year_basis, inclusion: { in: %w[unknown first_release production] }
    before_validation :reset_changed_year_provenance
    before_save :preserve_year_history
  end

  def displayed_year_basis
    return year_basis unless persisted? && has_children?

    records = state_leaves.select { |record| record.year.present? }
    bases = records.map(&:year_basis).uniq
    return 'unknown' if bases.empty?

    bases.one? ? bases.first : 'mixed'
  end

  def year_basis_label
    LABELS.fetch(displayed_year_basis)
  end

  def year_basis_description
    descriptions = {
      'unknown' => 'Origine de l’année non précisée',
      'first_release' => 'Première diffusion ou sortie originale',
      'production' => 'Année de production',
      'mixed' => 'Années de conventions différentes'
    }
    descriptions.fetch(displayed_year_basis)
  end

  private

  def reset_changed_year_provenance
    return unless will_save_change_to_year?
    return if will_save_change_to_year_basis? || will_save_change_to_year_evidence?

    self.year_basis = 'unknown'
    self.year_evidence = {}
  end

  def preserve_year_history
    return unless persisted? && year_provenance_changed?

    self.year_history = year_history + [{
      'year' => year_in_database, 'basis' => year_basis_in_database,
      'evidence' => year_evidence_in_database, 'replaced_at' => Time.current.iso8601
    }]
  end

  def year_provenance_changed?
    will_save_change_to_year? || will_save_change_to_year_basis? || will_save_change_to_year_evidence?
  end
end
