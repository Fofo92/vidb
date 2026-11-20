class AddCaptureOverrideToTvRecordingIntents < ActiveRecord::Migration[8.1]
  def change
    add_column :tv_recording_intents, :capture_override, :jsonb, default: {}, null: false
  end
end
