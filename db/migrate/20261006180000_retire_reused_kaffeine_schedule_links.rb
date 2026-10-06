class RetireReusedKaffeineScheduleLinks < ActiveRecord::Migration[8.1]
  def up
    add_column :tv_kaffeine_schedule_links, :retired_at, :datetime
    remove_index :tv_kaffeine_schedule_links, name: "index_tv_kaffeine_schedule_links_on_kaffeine_key"
    add_index :tv_kaffeine_schedule_links, :kaffeine_key, unique: true,
              where: "retired_at IS NULL", name: "index_unique_active_kaffeine_schedule_key"
  end

  def down
    raise ActiveRecord::IrreversibleMigration, "Historical links can share a reused Kaffeine key"
  end
end
