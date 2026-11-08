class CreateDvdPreparations < ActiveRecord::Migration[8.1]
  def change
    create_table :dvd_preparations do |t|
      t.string :ean, null: false, limit: 13
      t.string :provisional_title
      t.integer :announced_content_count
      t.text :notes
      t.jsonb :external_titles, null: false, default: []
      t.string :lookup_status, null: false, default: "pending"
      t.datetime :lookup_checked_at
      t.datetime :last_scanned_at, null: false, default: -> { "CURRENT_TIMESTAMP" }
      t.timestamps
    end
    add_index :dvd_preparations, :ean, unique: true
    add_check_constraint :dvd_preparations, "announced_content_count IS NULL OR announced_content_count > 0",
                         name: "dvd_preparations_positive_content_count"
  end
end
