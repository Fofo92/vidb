# frozen_string_literal: true

class RecordCopyConditionsController < ApplicationController
  before_action :load_copy

  def edit
    prepare_page
  end

  def update
    values = condition_params
    VideoAssets::ConditionUpdate.new(@asset, attributes: values.except('fingerprint'),
                                             fingerprint: values['fingerprint'], user: current_user).call
    redirect_to record_path(@record), notice: 'État de la copie enregistré.', status: :see_other
  rescue VideoAssets::ConditionUpdate::Stale => e
    show_error([e.message], :conflict)
  rescue ActiveRecord::RecordInvalid => e
    show_error(e.record.errors.full_messages, :unprocessable_content)
  rescue ArgumentError
    show_error(['La durée conservée doit être un nombre entier de minutes, entre 1 et 1440.'], :unprocessable_content)
  end

  private

  def condition_params
    params.require(:copy_condition).permit(:fingerprint, :integrality, :damage, :retained_portion,
                                           :retained_duration_minutes, :note).to_h
  end

  def load_copy
    @record = Record.find(params[:record_id])
    @asset = @record.video_assets.find(params[:copy_id])
  end

  def prepare_page
    @condition = @asset.effective_condition
    @fingerprint = VideoAssets::ConditionUpdate.fingerprint(@asset)
  end

  def show_error(messages, status)
    @errors = messages
    @asset.reload
    prepare_page
    render :edit, status: status
  end
end
