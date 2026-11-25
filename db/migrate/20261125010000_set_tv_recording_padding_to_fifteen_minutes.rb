# frozen_string_literal: true

class SetTvRecordingPaddingToFifteenMinutes < ActiveRecord::Migration[8.1]
  def change
    %i[
      requested_padding_before_seconds
      requested_padding_after_seconds
      effective_padding_before_seconds
      effective_padding_after_seconds
    ].each do |column|
      change_column_default :tv_recording_intents, column, from: 600, to: 900
    end
  end
end
