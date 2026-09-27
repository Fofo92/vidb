class CreateTvKaffeineScheduleLinks < ActiveRecord::Migration[8.1]
  def change
    create_table :tv_kaffeine_schedule_links do |t|
      t.references :recording_intent, null: false,
                                     foreign_key: { to_table: :tv_recording_intents },
                                     index: { unique: true }
      t.bigint :kaffeine_key, null: false
      t.string :origin, null: false
      t.string :name, null: false
      t.string :channel, null: false
      t.timestamptz :starts_at, null: false
      t.integer :duration_seconds, null: false
      t.integer :repeat_mask, null: false
      t.timestamps
    end

    add_index :tv_kaffeine_schedule_links, :kaffeine_key, unique: true
    add_check_constraint :tv_kaffeine_schedule_links,
                         "kaffeine_key BETWEEN 1 AND 4294967295",
                         name: "tv_kaffeine_schedule_links_key_check"
    add_check_constraint :tv_kaffeine_schedule_links,
                         "duration_seconds BETWEEN 1 AND 86399",
                         name: "tv_kaffeine_schedule_links_duration_check"
    add_check_constraint :tv_kaffeine_schedule_links,
                         "repeat_mask BETWEEN 0 AND 127",
                         name: "tv_kaffeine_schedule_links_repeat_check"
    add_check_constraint :tv_kaffeine_schedule_links,
                         "origin IN ('created_by_vidb', 'preexisting')",
                         name: "tv_kaffeine_schedule_links_origin_check"
  end
end
