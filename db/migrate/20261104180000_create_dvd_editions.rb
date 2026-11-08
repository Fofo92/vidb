class CreateDvdEditions < ActiveRecord::Migration[8.1]
  def change
    create_table :dvd_editions do |t|
      t.references :record, null: false, foreign_key: { on_delete: :cascade }
      t.string :ean, limit: 13, null: false
      t.index :ean, unique: true
      t.timestamps
    end
  end
end
