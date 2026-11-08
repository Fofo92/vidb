class CreateDvdContents < ActiveRecord::Migration[8.1]
  def change
    create_table :dvd_contents do |t|
      t.references :dvd_edition, null: false, foreign_key: { on_delete: :cascade }
      t.references :record, null: false, foreign_key: { on_delete: :cascade }
      t.references :language_version, foreign_key: true
      t.string :audio_languages, null: false, default: ""
      t.string :subtitle_languages, null: false, default: ""
      t.timestamps
      t.index [:dvd_edition_id, :record_id], unique: true
    end
  end
end
