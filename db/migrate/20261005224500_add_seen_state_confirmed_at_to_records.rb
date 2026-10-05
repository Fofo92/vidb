class AddSeenStateConfirmedAtToRecords < ActiveRecord::Migration[8.1]
  def change
    add_column :records, :seen_state_confirmed_at, :datetime
  end
end
