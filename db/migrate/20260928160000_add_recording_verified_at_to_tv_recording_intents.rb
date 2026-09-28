class AddRecordingVerifiedAtToTvRecordingIntents < ActiveRecord::Migration[8.1]
  def change
    add_column :tv_recording_intents, :recording_verified_at, :datetime
  end
end
