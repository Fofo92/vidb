class RecordsController < ApplicationController
  before_action :set_record, only: %i[new_child show edit update destroy]

  def index
    @q = Record.ransack(params[:q])
    @record_filter = RecordIndexFilter.new(filter_params, scope: @q.result)
    results = @record_filter.call
    @result_count = results.count
    @records = results.order(:french_title, :id).page(params[:page])
  rescue ActiveRecord::RecordNotFound
    redirect_to records_path, alert: "Arbre introuvable ou critère invalide."
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

  def filter_params
    params.fetch(:filters, ActionController::Parameters.new)
          .permit(:country_id, :gender_id, :language_version_id, :medium_id,
                  :year, :record_kind, :tree_id, :display, :missing, :review)
  end

  def set_record
    @record = Record.find(params[:id])
  end

  def record_params
    params.require(:record).permit(
      :original_title, :french_title, :length_in_mn, :year,
      :is_recorded, :is_seen, :is_available, :abstract, :rank, :language_version_id,
      :is_checked, :record_kind, :parent_id,
      medium_ids: [], gender_ids: [], country_ids: []
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
