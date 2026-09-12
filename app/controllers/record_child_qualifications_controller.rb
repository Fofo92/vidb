class RecordChildQualificationsController < ApplicationController
  before_action :set_record

  def edit
    prepare_page
  end

  def update
    operation = build_qualification

    if operation.call
      redirect_to record_path(@record), notice: update_notice
    else
      render_update_error(operation)
    end
  end

  private

  def set_record
    @record = Record.find(params[:record_id])
  end

  def qualification_params
    params.require(:record_child_qualification).permit(
      :record_kind,
      child_ids: []
    )
  end

  def build_qualification
    RecordChildQualification.new(
      parent: @record,
      child_ids: qualification_params[:child_ids],
      record_kind: qualification_params[:record_kind]
    )
  end

  def render_update_error(operation)
    @qualification = operation
    prepare_page
    render :edit, status: :unprocessable_content
  end

  def update_notice
    "La nature des enfants sélectionnés a été mise à jour."
  end

  def prepare_page
    @qualification_targets = @record.allowed_record_kinds_for_child_qualification
    @qualifiable_children = qualifiable_children
    @preserved_children = preserved_children
    @selected_child_ids = selected_child_ids
    @selected_record_kind = selected_record_kind
  end

  def ordered_children
    @record.children.order(:rank, :id)
  end

  def qualifiable_children
    ordered_children.where(record_kind: "undetermined")
  end

  def preserved_children
    ordered_children.where.not(record_kind: "undetermined")
  end

  def selected_child_ids
    return Array(@qualification.child_ids).map(&:to_s) if @qualification

    qualifiable_children.ids.map(&:to_s)
  end

  def selected_record_kind
    @qualification&.record_kind || @qualification_targets.first
  end
end
