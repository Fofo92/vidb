class CreateTvGuideChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :tv_guide_channels do |t|
      t.references :guide_source, null: false, foreign_key: { to_table: :tv_guide_sources }
      t.references :channel, null: true, foreign_key: { to_table: :tv_channels }
      t.string :external_id, null: false
      t.jsonb :display_names, default: [], null: false
      t.timestamps
    end

    add_index :tv_guide_channels,
              %i[guide_source_id external_id],
              unique: true
  end
end
