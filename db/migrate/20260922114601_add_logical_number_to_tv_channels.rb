class AddLogicalNumberToTvChannels < ActiveRecord::Migration[8.1]
  def change
    add_column :tv_channels, :logical_number, :integer
    add_unique_index
    add_positive_constraint
  end

  private

  def add_unique_index
    add_index(
      :tv_channels,
      :logical_number,
      unique: true
    )
  end

  def add_positive_constraint
    add_check_constraint(
      :tv_channels,
      "logical_number > 0",
      name: "tv_channels_logical_number_positive_check"
    )
  end
end
