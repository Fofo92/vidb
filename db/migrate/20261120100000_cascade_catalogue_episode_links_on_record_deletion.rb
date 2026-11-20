# frozen_string_literal: true

class CascadeCatalogueEpisodeLinksOnRecordDeletion < ActiveRecord::Migration[8.1]
  def up
    remove_foreign_key :catalogue_episode_links, :records
    add_foreign_key :catalogue_episode_links, :records, on_delete: :cascade
  end

  def down
    remove_foreign_key :catalogue_episode_links, :records
    add_foreign_key :catalogue_episode_links, :records
  end
end
