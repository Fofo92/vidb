class CreateCatalogueEpisodeLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :catalogue_episode_links do |table|
      table.references :record, null: false, foreign_key: true
      table.string :provider, null: false
      table.bigint :external_series_id, null: false
      table.bigint :external_episode_id, null: false
      table.integer :local_season_number, null: false
      table.integer :local_episode_number, null: false
      table.integer :external_season_number, null: false
      table.integer :external_episode_number, null: false
      table.jsonb :evidence, null: false, default: {}
      table.timestamps
    end
    add_index :catalogue_episode_links, [:provider, :external_episode_id], unique: true,
              name: 'index_unique_catalogue_external_episode'
    add_index :catalogue_episode_links, [:provider, :record_id], unique: true,
              name: 'index_unique_catalogue_record_provider'
  end
end
