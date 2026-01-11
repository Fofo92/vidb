class CreateMedia < ActiveRecord::Migration[7.1]
  def change
    create_table :media do |t|
      t.string :short_name
      t.string :long_name

      t.timestamps
    end
  end
end
