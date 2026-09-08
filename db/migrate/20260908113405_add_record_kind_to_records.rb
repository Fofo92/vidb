class AddRecordKindToRecords < ActiveRecord::Migration[8.1]
  def change
    add_column(
      :records,
      :record_kind,
      :string,
      default: "undetermined",
      null: false
    )

    add_check_constraint(
      :records,
      <<~SQL.squish,
        record_kind IN (
          'undetermined',
          'standalone_video',
          'series',
          'season',
          'episode'
        )
      SQL
      name: "records_record_kind_check"
    )
  end
end
