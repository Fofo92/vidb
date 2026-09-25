class CreateTvRecordingIntents < ActiveRecord::Migration[8.1]
  PADDING_COLUMNS = %i[
    requested_padding_before_seconds
    requested_padding_after_seconds
    effective_padding_before_seconds
    effective_padding_after_seconds
  ].freeze

  def change
    create_recording_intents
    add_padding_constraints
    add_programme_interval_constraint
    add_status_constraint
  end

  private

  def create_recording_intents
    create_table :tv_recording_intents do |t|
      add_broadcast_observation_reference(t)

      t.timestamptz :programme_starts_at, null: false
      t.timestamptz :programme_ends_at, null: false
      add_padding_columns(t)
      t.string :status, default: "selected", null: false
      t.timestamps
    end
  end

  def add_status_constraint
    add_check_constraint(
      :tv_recording_intents,
      "status IN ('selected', 'cancelled')",
      name: "tv_recording_intents_status_check"
    )
  end

  def add_padding_constraints
    PADDING_COLUMNS.each do |column|
      add_check_constraint(
        :tv_recording_intents,
        "#{column} >= 0",
        name: "tv_recording_intents_#{column}_check"
      )
    end
  end

  def add_programme_interval_constraint
    add_check_constraint(
      :tv_recording_intents,
      "programme_ends_at > programme_starts_at",
      name: "tv_recording_intents_programme_interval_check"
    )
  end

  def add_padding_columns(table)
    table.integer :requested_padding_before_seconds, default: 600, null: false
    table.integer :requested_padding_after_seconds, default: 600, null: false
    table.integer :effective_padding_before_seconds, default: 600, null: false
    table.integer :effective_padding_after_seconds, default: 600, null: false
  end

  def add_broadcast_observation_reference(table)
    table.references(
      :broadcast_observation,
      null: false,
      foreign_key: { to_table: :tv_broadcast_observations },
      index: { unique: true }
    )
  end
end
