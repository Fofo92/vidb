class CreateJoinTableRecordMedium < ActiveRecord::Migration[7.1]
  def change
    create_join_table :records, :media do |t|
      # t.index [:record_id, :medium_id]
      # t.index [:medium_id, :record_id]
    end
  end
end
