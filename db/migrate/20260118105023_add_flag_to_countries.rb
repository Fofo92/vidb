class AddFlagToCountries < ActiveRecord::Migration[7.1]
  def change
    add_column :countries, :flag, :string
  end
end
