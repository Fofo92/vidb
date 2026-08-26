class RecordsController < ApplicationController
  before_action :set_record, only: %i[new_child show edit update destroy]

  def index
    # @records = Record.order(:french_title).all.page(params[:page])
    @q = Record.ransack(params[:q])
    if params[:q].present?
      @records = @q.result(distinct: true).order(:french_title).page(params[:page])
    else
      @records = Record.roots.order(:french_title).all.page(params[:page])
    end
  end

  def show
  end

  def new
    @record = Record.new
  end

  def new_child
    parent_id = @record.id
    @record = Record.new
    @record.parent_id = parent_id
    @record.country_ids = @record.parent.country_ids
    @record.gender_ids = @record.parent.gender_ids
    @record.medium_ids = @record.parent.medium_ids
    @record.language_version_id = @record.parent.language_version_id
  end

  def create
    @record = Record.new(record_params)

    if @record.save
      redirect_after_create
    else
      template = @record.parent ? :new_child : :new
      render template, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @record.update(record_params)
      redirect_to(
        record_path(@record),
        notice: "L'enregistrement a été mis à jour avec succès."
      )
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    parent = @record.parent
    @record.destroy
    redirect_to parent ? record_path(parent) : records_path
  end

  private

  def set_record
    @record = Record.find(params[:id])
  end

  def record_params
    params.require(:record).permit(
      :original_title, :french_title, :length_in_mn, :year,
      :is_recorded, :is_seen, :is_available, :abstract, :rank, :language_version_id,
      :is_checked, :parent_id, medium_ids: [], gender_ids: [], country_ids: []
    )
  end

  def redirect_after_create
    destination = @record.parent || @record

    redirect_to(
      record_path(destination),
      notice: "L'enregistrement a été créé avec succès."
    )
  end
end
