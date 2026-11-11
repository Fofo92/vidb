class RecordChildQualificationsController < ApplicationController
  before_action :set_record

  def edit
    prepare_page
  end

  def update
    operation = build_qualification
    if operation.call
      redirect_to record_path(@record), notice: "Les enfants sélectionnés ont été mis à jour."
    else
      @qualification = operation
      prepare_page
      render :edit, status: :unprocessable_content
    end
  end

  def metadata_modes
    return head :unprocessable_content unless RecordMetadataValues.forcing_parent?(@record)

    if RecordMetadataModeUpdate.new(@record, attributes: branch_mode_params).call
      redirect_to edit_record_child_qualification_path(@record), status: :see_other,
                                                                 notice: 'Règle de la branche enregistrée.'
    else
      @branch_mode_errors = @record.errors.full_messages
      @record.reload
      prepare_page
      render :edit, status: :unprocessable_content
    end
  end

  private

  def branch_mode_params
    params.permit(*RecordMetadataValues::MODE_ATTRIBUTES.values)
  end

  def prepare_branch_review
    return unless RecordMetadataValues.forcing_parent?(@record)

    submitted_modes = branch_mode_params
    @branch_modes = RecordMetadataValues::MODE_ATTRIBUTES.transform_values do |attribute|
      submitted_modes[attribute].presence_in(RecordMetadataValues::MODES.keys) || @record.public_send(attribute)
    end
    @branch_review = RecordMetadataInheritanceReview.new(root: @record, modes: @branch_modes).call
  end

  def set_record
    @record = Record.find(params[:record_id])
  end

  def metadata_params
    params.require(:record_child_qualification).permit(
      :parent_snapshot, child_ids: [], snapshots: {}, rows: {},
                        common: [:record_kind, :year, :year_basis, :language_version_id, :is_seen, :is_checked,
                                 :copy_language_version_id, :copy_medium_id,
                                 { fields: [], gender_ids: [], country_ids: [], medium_ids: [] }]
    )
  end

  def build_qualification
    if params[:record_child_qualification].key?(:common)
      @submitted = metadata_params.to_h
      return RecordChildrenUpdate.new(
        parent: @record, child_ids: @submitted["child_ids"], common: @submitted.fetch("common", {}),
        rows: @submitted.fetch("rows", {}),
        snapshots: { children: @submitted.fetch("snapshots", {}), parent: @submitted["parent_snapshot"] }
      )
    end

    choices = params.require(:record_child_qualification).permit(:record_kind, child_ids: [])
    RecordChildQualification.new(parent: @record, child_ids: choices[:child_ids], record_kind: choices[:record_kind])
  end

  def prepare_page
    @qualification_targets = @record.allowed_record_kinds_for_child_qualification
    @children = @record.children.order(:rank, :id).includes(:genders, :countries, :media, :language_version,
                                                            :video_assets)
    @selected_child_ids = selected_child_ids
    kind = @qualification.record_kind if @qualification.respond_to?(:record_kind)
    @common_values = @submitted&.fetch("common", {}) || { "record_kind" => kind || @qualification_targets.first }
    @row_values = @submitted&.fetch("rows", {}) || {}
    prepare_choices
    prepare_branch_review
  end

  def selected_child_ids
    return Array(@qualification.child_ids).map(&:to_s) if @qualification

    @children.select(&:record_kind_undetermined?).map { |child| child.id.to_s }
  end

  def prepare_choices
    @genders = Gender.order(:name).pluck(:name, :id)
    @countries = Country.order(:long_name).pluck(:long_name, :id)
    @media = Medium.order(:short_name).pluck(:short_name, :id)
    @languages = LanguageVersion.order(:short_name).pluck(:short_name, :id)
  end
end
