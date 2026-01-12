class AddIsCheckedToRecords < ActiveRecord::Migration[7.1]
  def change
    add_column :records, :is_checked, :boolean, default: false
  end
end
