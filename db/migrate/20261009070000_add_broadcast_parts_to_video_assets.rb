class AddBroadcastPartsToVideoAssets < ActiveRecord::Migration[8.1]
  def change
    add_column :records, :broadcast_part_count, :integer, null: false, default: 1
    add_column :video_assets, :broadcast_part_number, :integer
    add_check_constraint :records, 'broadcast_part_count > 0', name: 'records_broadcast_part_count_check'
    add_check_constraint :video_assets, 'broadcast_part_number IS NULL OR broadcast_part_number > 0',
                         name: 'video_assets_broadcast_part_number_check'
  end
end
