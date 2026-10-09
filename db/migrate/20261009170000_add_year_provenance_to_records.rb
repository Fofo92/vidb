# frozen_string_literal: true

class AddYearProvenanceToRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :records, :year_basis, :string, null: false, default: 'unknown'
    add_column :records, :year_evidence, :jsonb, null: false, default: {}
    add_column :records, :year_history, :jsonb, null: false, default: []
    add_check_constraint :records, "year_basis IN ('unknown', 'first_release', 'production')",
                         name: 'records_year_basis_check'
  end
end
