class AddMetadataToTvBroadcastObservations <
    ActiveRecord::Migration[8.1]
  METADATA_FIELDS = %i[
    titles
    subtitles
    descriptions
    categories
    episode_numbers
  ].freeze

  def change
    add_metadata_columns
    add_metadata_type_constraints
  end

  private

  def add_metadata_columns
    change_table :tv_broadcast_observations, bulk: true do |t|
      t.string :source_start
      t.string :source_stop
      METADATA_FIELDS.each do |field|
        t.jsonb field, default: [], null: false
      end
    end
  end

  def add_metadata_type_constraints
    METADATA_FIELDS.each do |field|
      add_check_constraint(
        :tv_broadcast_observations,
        "jsonb_typeof(#{field}) = 'array'",
        name: "tv_broadcast_observations_#{field}_array_check"
      )
    end
  end
end
