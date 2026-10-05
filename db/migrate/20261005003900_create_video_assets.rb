class CreateVideoAssets < ActiveRecord::Migration[8.1]
  CHECK_CONSTRAINTS = {
    "status IN ('present', 'deleted')" => "video_assets_status_check",
    "status <> 'present' OR NULLIF(BTRIM(last_known_path), '') IS NOT NULL" =>
      "video_assets_present_path_check",
    "duration_minutes IS NULL OR duration_minutes > 0" =>
      "video_assets_duration_check",
    "byte_size IS NULL OR byte_size >= 0" =>
      "video_assets_byte_size_check"
  }.freeze

  def change
    create_video_assets
    add_present_path_index
    add_video_asset_constraints
  end

  private

  def create_video_assets
    create_table :video_assets do |t|
      t.references :record, null: false, foreign_key: true
      t.string :status, null: false, default: "present"
      t.text :last_known_path
      t.integer :duration_minutes
      t.bigint :byte_size
      t.string :container
      t.datetime :observed_at

      t.timestamps
    end
  end

  def add_present_path_index
    add_index :video_assets,
              :last_known_path,
              unique: true,
              where: "status = 'present' AND last_known_path IS NOT NULL",
              name: "index_unique_present_video_asset_path"
  end

  def add_video_asset_constraints
    CHECK_CONSTRAINTS.each do |expression, name|
      add_check_constraint :video_assets, expression, name: name
    end
  end
end
