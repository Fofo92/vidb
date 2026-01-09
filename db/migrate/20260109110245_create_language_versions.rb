class CreateLanguageVersions < ActiveRecord::Migration[7.1]
  def change
    create_table :language_versions do |t|
      t.string :long_name
      t.string :short_name

      t.timestamps
    end
  end
end
