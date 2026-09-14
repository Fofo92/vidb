class CreateTvChannels < ActiveRecord::Migration[8.1]
  def change
    create_table :tv_channels do |t|
      t.string :display_name, null: false
      t.boolean :enabled, default: true, null: false

      t.timestamps
    end
  end
end
