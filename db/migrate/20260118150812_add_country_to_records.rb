class AddCountryToRecords < ActiveRecord::Migration[7.1]
  def change
    add_reference :records, :country, null: true, foreign_key: true
  end
end
