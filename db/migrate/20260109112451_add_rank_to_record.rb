class AddRankToRecord < ActiveRecord::Migration[7.1]
  def change
    add_column :records, :rank, :integer
  end
end
