# frozen_string_literal: true

class AddGenreProvenanceToRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :records, :genre_provenance, :jsonb, default: {}, null: false
  end
end
