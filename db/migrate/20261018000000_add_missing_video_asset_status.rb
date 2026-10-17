class AddMissingVideoAssetStatus < ActiveRecord::Migration[8.1]
  def up
    remove_check_constraint :video_assets, name: 'video_assets_status_check'
    add_check_constraint :video_assets, "status IN ('present', 'missing', 'deleted')", name: 'video_assets_status_check'
  end

  def down
    raise ActiveRecord::IrreversibleMigration, 'Les copies introuvables conservent leur historique'
  end
end
