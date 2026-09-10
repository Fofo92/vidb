class RecordHierarchyPlacementsController < ApplicationController
  before_action :set_record

  def edit
    prepare_parent_search(@record)
  end

  def update
    @record.parent = requested_parent

    if @record.save
      redirect_to(
        record_path(@record),
        notice: "La fiche a été déplacée avec succès."
      )
    else
      prepare_parent_search(Record.find(@record.id))
      render :edit, status: :unprocessable_content
    end
  end

  private

  def prepare_parent_search(search_record)
    @query = params[:q].to_s
    @candidate_parents = RecordHierarchyParentSearch
                         .new(record: search_record, query: @query)
                         .results
                         .page(params[:page])
  end

  def requested_parent
    parent_id = hierarchy_placement_params.fetch(:parent_id)
    return if parent_id.blank?

    Record.find(parent_id)
  end

  def hierarchy_placement_params
    params.require(:hierarchy_placement).permit(:parent_id)
  end

  def set_record
    @record = Record.find(params[:record_id])
    @current_parent = @record.parent
    @descendant_count = @record.descendants.count
  end
end
