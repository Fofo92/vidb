class CreateTvGuideSources < ActiveRecord::Migration[8.1]
  def change
    create_table :tv_guide_sources do |t|
      t.string :name, null: false
      t.string :display_name, null: false
      t.boolean :enabled, default: true, null: false
      t.string :time_zone, default: "Europe/Paris", null: false

      t.timestamps
    end

    add_index :tv_guide_sources, :name, unique: true
  end
end
