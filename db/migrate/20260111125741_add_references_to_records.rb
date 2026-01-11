class AddReferencesToRecords < ActiveRecord::Migration[7.1]
  def change
    add_reference :records, :language_version, null: true, foreign_key: true
  end
end
