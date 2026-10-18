class AddLastVerifiedAtToTvGuideSources < ActiveRecord::Migration[8.1]
  def change
    add_column :tv_guide_sources, :last_verified_at, :datetime
  end
end
