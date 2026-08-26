class GendersController < ApplicationController
  before_action :set_gender, only: [:edit, :update, :destroy]

  def index
    @genders = Gender.order(:name).all
  end

  def new
    @gender = Gender.new
  end

  def create
    @gender = Gender.new(gender_params)

    if @gender.save
      redirect_to(
        genders_path,
        notice: "Le genre cinématographique a été créé avec succès."
      )
    else
      render :new, status: :unprocessable_content
    end
  end

  def edit
  end

  def update
    if @gender.update(gender_params)
      redirect_to genders_path, notice: "Le genre cinématographique a été mis à jour avec succès."
    else
      render :edit, status: :unprocessable_content
    end
  end

  def destroy
    @gender.destroy
    redirect_to genders_path
  end

  private

  def set_gender
    @gender = Gender.find(params[:id])
  end

  def gender_params
    params.require(:gender).permit(:name, :comment)
  end

end
