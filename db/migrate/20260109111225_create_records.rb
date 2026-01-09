class CreateRecords < ActiveRecord::Migration[7.1]
  def change
    create_table :records do |t|
      t.string :original_title
      t.string :french_title
      t.integer :length_in_mn
      t.integer :year
      t.boolean :is_seen, default: false
      t.boolean :is_available, default: false
      t.text :abstract

      t.timestamps
    end
  end
end
