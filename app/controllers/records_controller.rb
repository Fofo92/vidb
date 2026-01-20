class RecordsController < ApplicationController
  before_action :set_record, only: [:new_child, :show, :edit, :update, :destroy]

  def index
    # @records = Record.order(:french_title).all.page(params[:page])
    @q = Record.ransack(params[:q])
    @records = @q.result(distinct: true).order(:french_title).page(params[:page])
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

    if @record.valid?
      @record.save
      redirect_to record_path(@record.parent_id || @record.id) || records_path, notice: "L'enregistrement a été créée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @record.valid?
      @record.update(record_params)
      redirect_to records_path, notice: "L'enregistrement a été mise à jour avec succès."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @record.destroy
    redirect_to record_path
  end

  private

  def set_record
    puts "Entering set_record"
    @record = Record.find(params[:id])
  end

  def record_params
    params.require(:record).permit(
      :original_title, :french_title, :length_in_mn, :year,
      :is_recorded, :is_seen, :is_available, :abstract, :rank, :language_version_id,
      :is_checked, :parent_id, medium_ids: [], gender_ids: [], country_ids: []
    )
  end
end
