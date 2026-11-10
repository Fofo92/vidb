class AddMetadataForcingToRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :records, :descendant_country_mode, :string, default: 'current', null: false
    add_column :records, :descendant_genre_mode, :string, default: 'current', null: false
  end
end
