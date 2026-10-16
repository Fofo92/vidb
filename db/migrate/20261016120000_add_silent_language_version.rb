# frozen_string_literal: true

class AddSilentLanguageVersion < ActiveRecord::Migration[8.1]
  def up
    execute 'LOCK TABLE language_versions IN SHARE ROW EXCLUSIVE MODE'
    execute <<~SQL
      INSERT INTO language_versions (short_name, long_name, created_at, updated_at)
      SELECT 'MUET', 'Muet', CURRENT_TIMESTAMP, CURRENT_TIMESTAMP
      WHERE NOT EXISTS (
        SELECT 1 FROM language_versions
        WHERE UPPER(short_name) = 'MUET' OR LOWER(long_name) = 'muet'
      )
    SQL
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'La qualification Muet peut déjà être utilisée par des fiches ou copies.'
  end
end
