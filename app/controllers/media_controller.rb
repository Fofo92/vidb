class MediaController < ApplicationController
  before_action :set_medium, only: %i[edit update destroy]

  def index
    @media = Medium.order(:long_name).all
  end

  def new
    @medium = Medium.new
  end

  def create
    @medium = Medium.new(medium_params)

    if @medium.save
      redirect_to media_path, notice: "Le support a été créé avec succès."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @medium.update(medium_params)
      redirect_to media_path, notice: "Le support a été mis à jour avec succès."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @medium.destroy
    redirect_to media_path
  end

  private

  def set_medium
    @medium = Medium.find(params[:id])
  end

  def medium_params
    params.require(:medium).permit(:short_name, :long_name)
  end
end
