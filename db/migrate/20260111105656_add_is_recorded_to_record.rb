class AddIsRecordedToRecord < ActiveRecord::Migration[7.1]
  def change
    add_column :records, :is_recorded, :boolean
  end
end
