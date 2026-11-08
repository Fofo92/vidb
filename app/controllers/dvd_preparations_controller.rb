class DvdPreparationsController < ApplicationController
  before_action :set_preparation, only: %i[show update lookup]

  def index
    load_preparations
  end

  def show
  end

  def create
    preparation = DvdPreparation.create_or_find_by!(ean: params[:ean].to_s.strip)
    preparation.update!(last_scanned_at: Time.current)
    DvdPreparationLookup.new.call(preparation) if preparation.lookup_status == "pending"
    redirect_to dvd_preparations_path, notice: "EAN #{preparation.ean} conservé. Tu peux scanner le suivant.",
                                       status: :see_other
  rescue ActiveRecord::RecordInvalid => e
    load_preparations
    flash.now[:alert] = e.record.errors.full_messages.to_sentence
    render :index, status: :unprocessable_content
  end

  def update
    if @preparation.update(preparation_params)
      redirect_to dvd_preparation_path(@preparation), notice: "Préparation enregistrée.", status: :see_other
    else
      render :show, status: :unprocessable_content
    end
  end

  def lookup
    DvdPreparationLookup.new.call(@preparation)
    redirect_to dvd_preparation_path(@preparation), status: :see_other
  end

  private

  def set_preparation
    @preparation = DvdPreparation.find(params[:id])
  end

  def load_preparations
    scope = DvdPreparation.includes(dvd_edition: :record)
    scope = scope.awaiting_identification if params[:pending] == "1"
    @preparations = scope.order(last_scanned_at: :desc, id: :desc).page(params[:page])
  end

  def preparation_params
    params.require(:dvd_preparation).permit(:provisional_title, :announced_content_count, :notes)
  end
end
