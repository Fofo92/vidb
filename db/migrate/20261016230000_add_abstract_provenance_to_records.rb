# frozen_string_literal: true

class AddAbstractProvenanceToRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :records, :abstract_provenance, :jsonb, default: {}, null: false
  end
end
