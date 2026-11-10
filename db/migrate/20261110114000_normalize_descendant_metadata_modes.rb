class NormalizeDescendantMetadataModes < ActiveRecord::Migration[8.1]
  def up
    normalize_mode(:force_descendant_countries, :descendant_country_mode)
    normalize_mode(:force_descendant_genres, :descendant_genre_mode)
  end

  def down
    # The preceding migration's canonical schema already uses mode columns.
  end

  private

  def normalize_mode(legacy, mode)
    return unless column_exists?(:records, legacy)

    unless column_exists?(:records, mode)
      add_column :records, mode, :string, default: 'current', null: false
      migrate_enabled(legacy, mode)
    end
    remove_column :records, legacy
  end

  def migrate_enabled(legacy, mode)
    execute <<~SQL
      UPDATE #{connection.quote_table_name(:records)}
      SET #{connection.quote_column_name(mode)} = 'parent'
      WHERE #{connection.quote_column_name(legacy)} IS TRUE
    SQL
  end
end
