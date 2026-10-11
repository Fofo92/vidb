# frozen_string_literal: true

class AllowFilmCollectionsInRecords < ActiveRecord::Migration[8.1]
  def up
    replace_constraint(%w[undetermined standalone_video collection series season episode])
  end

  def down
    count = select_value("SELECT COUNT(*) FROM records WHERE record_kind = 'collection'").to_i
    if count.positive?
      raise ActiveRecord::IrreversibleMigration, 'Requalifier les collections avant de retirer ce type.'
    end

    replace_constraint(%w[undetermined standalone_video series season episode])
  end

  private

  def replace_constraint(kinds)
    remove_check_constraint :records, name: 'records_record_kind_check'
    values = kinds.map { |kind| connection.quote(kind) }.join(', ')
    add_check_constraint :records, "record_kind IN (#{values})", name: 'records_record_kind_check'
  end
end
