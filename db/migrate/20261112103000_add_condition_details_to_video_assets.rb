class AddConditionDetailsToVideoAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :video_assets, :condition_details, :jsonb, default: {}, null: false
    add_check_constraint :video_assets, "jsonb_typeof(condition_details) = 'object'",
                         name: 'video_assets_condition_object'
  end
end
