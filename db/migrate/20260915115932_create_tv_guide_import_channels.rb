class CreateTvGuideImportChannels < ActiveRecord::Migration[8.1]
  COVERAGE_INTERVAL_CHECK = <<~SQL.squish
    (
      programme_count = 0
      AND first_starts_at IS NULL
      AND last_ends_at IS NULL
    )
    OR
    (
      programme_count > 0
      AND first_starts_at IS NOT NULL
      AND last_ends_at IS NOT NULL
      AND last_ends_at > first_starts_at
    )
  SQL
  COUNTER_FIELDS = %i[
    programme_count
    gap_count
    total_gap_duration_seconds
  ].freeze

  JSON_ARRAY_FIELDS = %i[
    display_names
    gaps
  ].freeze

  def change
    create_import_channels
    add_counter_constraints
    add_json_array_constraints
    add_unique_import_channel_index
    add_coverage_interval_constraint
    add_gap_summary_constraints
  end

  private

  def add_coverage_interval_constraint
    add_check_constraint(
      :tv_guide_import_channels,
      COVERAGE_INTERVAL_CHECK,
      name: "tv_guide_import_channels_coverage_interval_check"
    )
  end

  def add_gap_summary_constraints
    add_check_constraint(
      :tv_guide_import_channels,
      "gap_count = jsonb_array_length(gaps)",
      name: "tv_guide_import_channels_gap_count_matches_gaps_check"
    )
    add_check_constraint(
      :tv_guide_import_channels,
      "gap_count > 0 OR total_gap_duration_seconds = 0",
      name: "tv_guide_import_channels_empty_gap_duration_check"
    )
  end

  def create_import_channels
    create_table :tv_guide_import_channels do |t|
      add_references(t)
      add_coverage_fields(t)
      t.timestamps
    end
  end

  def add_references(table)
    table.references :guide_import, null: false,
                                    foreign_key: { to_table: :tv_guide_imports }
    table.references :guide_channel, null: false,
                                     foreign_key: { to_table: :tv_guide_channels }
  end

  def add_coverage_fields(table)
    table.jsonb :display_names, default: [], null: false
    table.integer :programme_count, default: 0, null: false
    table.timestamptz :first_starts_at
    table.timestamptz :last_ends_at
    table.integer :gap_count, default: 0, null: false
    table.bigint :total_gap_duration_seconds, default: 0, null: false
    table.jsonb :gaps, default: [], null: false
  end

  def add_counter_constraints
    COUNTER_FIELDS.each do |field|
      add_check_constraint(
        :tv_guide_import_channels,
        "#{field} >= 0",
        name: "tv_guide_import_channels_#{field}_check"
      )
    end
  end

  def add_json_array_constraints
    JSON_ARRAY_FIELDS.each do |field|
      add_check_constraint(
        :tv_guide_import_channels,
        "jsonb_typeof(#{field}) = 'array'",
        name: "tv_guide_import_channels_#{field}_array_check"
      )
    end
  end

  def add_unique_import_channel_index
    add_index(
      :tv_guide_import_channels,
      %i[guide_import_id guide_channel_id],
      unique: true,
      name: "index_unique_tv_guide_import_channel"
    )
  end
end
