class CreateRecordRatings < ActiveRecord::Migration[8.1]
  def change
    create_table :record_ratings do |t|
      t.references :record, null: false, foreign_key: true
      t.references :user, null: false, foreign_key: true, index: false
      t.integer :value, null: false
      t.timestamps
    end

    add_index :record_ratings, %i[user_id record_id], unique: true
    add_check_constraint :record_ratings, 'value BETWEEN 1 AND 5', name: 'record_ratings_value_check'
  end
end
