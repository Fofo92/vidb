class RecordsController < ApplicationController
  before_action :set_record, only: [:show, :edit, :update, :destroy]

  def index
    @records = Record.order(:french_title).all
  end

	def show
  end

  def new
    @record = Record.new
  end

  def create
    @record = Record.new(record_params)

    if @record.valid?
      @record.save
      redirect_to records_path, notice: "L'enregistrement a été créée avec succès."
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
    redirect_to records_path
  end

  private

  def set_record
    @record = Record.find(params[:id])
  end

  def record_params
    params.require(:record).permit(
      :original_title,
      :french_title,
      :length_in_mn,
      :year,
      :is_seen,
      :is_available,
      :abstract)
  end
end
