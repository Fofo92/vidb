class CreateTvBroadcastObservations < ActiveRecord::Migration[8.1]
  CHECK_CONSTRAINTS = {
    fingerprint: "fingerprint ~ '^[0-9A-Fa-f]{64}$'",
    fingerprint_version: "fingerprint_version > 0",
    time_interval: "ends_at > starts_at"
  }.freeze

  def change
    create_broadcast_observations
    add_data_constraints
    add_fingerprint_index
    add_schedule_index
  end

  private

  def create_broadcast_observations
    create_table :tv_broadcast_observations do |t|
      t.references :guide_channel, null: false,
                                   foreign_key: { to_table: :tv_guide_channels }
      t.string :fingerprint, null: false
      t.integer :fingerprint_version, default: 1, null: false
      t.timestamptz :starts_at, null: false
      t.timestamptz :ends_at, null: false
      t.timestamps
    end
  end

  def add_data_constraints
    CHECK_CONSTRAINTS.each do |name, expression|
      add_check_constraint(
        :tv_broadcast_observations,
        expression,
        name: "tv_broadcast_observations_#{name}_check"
      )
    end
  end

  def add_fingerprint_index
    add_index(
      :tv_broadcast_observations,
      %i[fingerprint_version fingerprint],
      unique: true,
      name: "index_unique_tv_broadcast_observation_fingerprint"
    )
  end

  def add_schedule_index
    add_index(
      :tv_broadcast_observations,
      %i[guide_channel_id starts_at ends_at],
      name: "index_tv_broadcast_observations_on_channel_and_time"
    )
  end
end
