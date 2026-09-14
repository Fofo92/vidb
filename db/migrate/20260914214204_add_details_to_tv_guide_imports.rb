class AddDetailsToTvGuideImports < ActiveRecord::Migration[8.1]
  COUNTER_COLUMNS = %i[
    channel_count
    source_programme_count
    programme_count
    duplicate_programme_count
  ].freeze

  def change
    add_detail_columns
    add_counter_constraints
  end

  private

  def add_detail_columns
    change_table :tv_guide_imports, bulk: true do |t|
      t.datetime :started_at, default: -> { "CURRENT_TIMESTAMP" }, null: false
      t.datetime :finished_at
      t.jsonb :source_metadata, default: {}, null: false
      t.integer :channel_count, default: 0, null: false
      t.integer :source_programme_count, default: 0, null: false
      t.integer :programme_count, default: 0, null: false
      t.integer :duplicate_programme_count, default: 0, null: false
      t.text :error_message
    end
  end

  def add_counter_constraints
    COUNTER_COLUMNS.each do |column|
      add_check_constraint(
        :tv_guide_imports,
        "#{column} >= 0",
        name: "tv_guide_imports_#{column}_check"
      )
    end
  end
end
