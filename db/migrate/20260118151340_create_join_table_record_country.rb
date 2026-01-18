class CreateJoinTableRecordCountry < ActiveRecord::Migration[7.1]
  def change
    create_join_table :records, :countries do |t|
      # t.index [:record_id, :country_id]
      # t.index [:country_id, :record_id]
    end
  end
end
