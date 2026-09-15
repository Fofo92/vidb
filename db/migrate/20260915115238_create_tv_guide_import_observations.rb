class CreateTvGuideImportObservations <
    ActiveRecord::Migration[8.1]
  def change
    create_import_observations
    add_unique_import_observation_index
  end

  private

  def create_import_observations
    create_table :tv_guide_import_observations do |t|
      t.references :guide_import, null: false,
                                  foreign_key: { to_table: :tv_guide_imports }
      t.references :broadcast_observation, null: false,
                                           foreign_key: {
                                             to_table: :tv_broadcast_observations
                                           }
      t.timestamps
    end
  end

  def add_unique_import_observation_index
    add_index(
      :tv_guide_import_observations,
      %i[guide_import_id broadcast_observation_id],
      unique: true,
      name: "index_unique_tv_guide_import_observation"
    )
  end
end
