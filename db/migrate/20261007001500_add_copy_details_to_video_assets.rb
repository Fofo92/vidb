class AddCopyDetailsToVideoAssets < ActiveRecord::Migration[8.1]
  def change
    add_reference :video_assets, :medium, foreign_key: { to_table: :media }
    add_reference :video_assets, :language_version, foreign_key: true
    add_column :video_assets, :technical_details, :jsonb, default: {}, null: false
  end
end
