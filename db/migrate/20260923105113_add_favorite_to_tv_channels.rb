class AddFavoriteToTvChannels < ActiveRecord::Migration[8.1]
  def change
    add_column(
      :tv_channels,
      :favorite,
      :boolean,
      default: true,
      null: false
    )
  end
end
