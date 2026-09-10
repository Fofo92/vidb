class RecordHierarchyPlacementsController < ApplicationController
  before_action :set_record

  def edit
  end

  private

  def set_record
    @record = Record.find(params[:record_id])
  end
end
