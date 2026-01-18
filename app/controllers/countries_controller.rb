class CountriesController < ApplicationController
  before_action :set_country, only: [:edit, :update, :destroy]

  def index
    @countries = Country.order(:long_name).all
  end

  def new
    @country = Country.new
  end

  def create
    @country = Country.new(country_params)

    if @gcountry.valid?
      @country.save
      redirect_to countries_path, notice: "Le pays a été crée avec succès."
    else
      render :new, status: :unprocessable_entity
    end
  end

  def edit
  end

  def update
    if @country.valid?
      @country.update(country_params)
      redirect_to countries_path, notice: "Le pays a été mis à jour avec succès."
    else
      render :edit, status: :unprocessable_entity
    end
  end

  def destroy
    @country.destroy
    redirect_to countries_path
  end

  private

  def set_country
    @country = Country.find(params[:id])
  end

  def country_params
    params.require(:country).permit(:short_name, :long_name, :flag)
  end
end
