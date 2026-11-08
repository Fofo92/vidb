class CreateCatalogueEpisodePartitions < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogue_episode_partitions do |t|
      t.references :record, null: false, foreign_key: { on_delete: :cascade }, index: { unique: true }
      t.bigint :external_series_id, null: false
      t.bigint :external_episode_id, null: false
      t.integer :external_season_number, null: false
      t.integer :external_episode_number, null: false
      t.integer :part_number, null: false
      t.integer :part_count, null: false
      t.jsonb :evidence, null: false, default: {}
      t.timestamps
      t.index [:external_episode_id, :part_number], unique: true, name: "index_unique_catalogue_episode_partition"
    end
    add_check_constraint :catalogue_episode_partitions,
                         "part_number > 0 AND part_count > 1 AND part_number <= part_count",
                         name: "catalogue_episode_partition_numbers"
  end
end
