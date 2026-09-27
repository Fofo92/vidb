class AddKaffeineNameToTvChannels < ActiveRecord::Migration[8.1]
  def change
    add_column(
      :tv_channels,
      :kaffeine_name,
      :string
    )
    add_index(
      :tv_channels,
      :kaffeine_name,
      unique: true
    )
  end
end
