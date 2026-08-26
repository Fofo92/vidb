class LanguageVersionsController < ApplicationController
  before_action :set_language_version, only: [:edit, :update, :destroy]

  def index
    @language_versions = LanguageVersion.order(:long_name).all
  end

  def new
    @language_version = LanguageVersion.new
  end

  def create
    @language_version = LanguageVersion.new(language_version_params)

    if @language_version.save
      redirect_to language_versions_path, notice: "La version linguistique a été créée avec succès."
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @language_version.update(language_version_params)
      redirect_to language_versions_path, notice: "La version linguistique a été mise à jour avec succès."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @language_version.destroy
    redirect_to language_versions_path
  end

  private

  def set_language_version
    @language_version = LanguageVersion.find(params[:id])
  end

  def language_version_params
    params.require(:language_version).permit(:short_name, :long_name)
  end
end
