class RecordChildQualificationsController < ApplicationController
  before_action :set_record

  def edit
    children = @record.children.order(:rank, :id)

    @qualification_targets =
      @record.allowed_record_kinds_for_child_qualification
    @qualifiable_children =
      children.where(record_kind: "undetermined")
    @preserved_children =
      children.where.not(record_kind: "undetermined")
  end

  private

  def set_record
    @record = Record.find(params[:record_id])
  end
end
