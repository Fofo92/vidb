class CreateJoinTableRecordGender < ActiveRecord::Migration[7.1]
  def change
    create_join_table :records, :genders do |t|
      # t.index [:record_id, :gender_id]
      # t.index [:gender_id, :record_id]
    end
  end
end
