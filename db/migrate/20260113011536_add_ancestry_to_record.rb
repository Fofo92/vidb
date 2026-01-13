class AddAncestryToRecord < ActiveRecord::Migration[7.1]
  def change
    add_column :records, :ancestry, :string
    add_index :records, :ancestry
  end
end
