# frozen_string_literal: true

module VideoAssets
  # Atomic data maintenance: only condition_details and the copy timestamp are written.
  class ConditionConventionApply
    def call(plan)
      @plan = plan
      validate_plan!
      counts = apply_changes
      { 'format' => ConditionConventionPlan::FORMAT, 'mode' => 'applied',
        'plan_digest' => @plan.fetch('plan_digest'), 'counts' => counts }
    end

    private

    def apply_changes
      counts = Hash.new(0)
      VideoAsset.transaction do
        @plan.fetch('changes').sort_by { |row| row.values_at('record_id', 'video_asset_id') }.each do |row|
          Record.lock.find(row.fetch('record_id'))
          asset = VideoAsset.lock.find(row.fetch('video_asset_id'))
          counts[apply_row(asset, row)] += 1
        end
      end
      counts
    end

    def validate_plan!
      valid = @plan.is_a?(Hash) && @plan['format'] == ConditionConventionPlan::FORMAT && @plan['version'] == 1 &&
              @plan['changes'].is_a?(Array)
      raise ArgumentError, 'Plan de qualification non reconnu' unless valid
      return if @plan['plan_digest'] == ConditionConventionPlan.digest(@plan.fetch('changes'))

      raise ArgumentError, 'Le contenu du plan a changé'
    end

    def apply_row(asset, row)
      return 'already_applied' if asset.condition_details == row.fetch('after')

      current = ConditionConventionPlan.fingerprint(asset)
      proposal = ConditionConventionPlan.proposal(asset)
      raise ArgumentError, "Copie #{asset.id} modifiée depuis l’aperçu : aucune qualification enregistrée." unless
        current == row.fetch('before_digest') && proposal == row.fetch('after')

      write_condition(asset, proposal)
      'applied'
    end

    def write_condition(asset, proposal)
      asset.condition_details = proposal
      raise ArgumentError, "Qualification invalide pour la copie #{asset.id}" unless asset.copy_condition_valid?

      # Avoid callbacks that recompute historical availability or viewing states.
      asset.update_columns(condition_details: proposal, updated_at: Time.current)
    end
  end
end
