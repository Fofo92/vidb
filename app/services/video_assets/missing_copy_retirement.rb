# frozen_string_literal: true

module VideoAssets
  # Close obsolete references only; no file, project or job is removed.
  class MissingCopyRetirement
    def initialize(user:, root: '/videos', guard: ReconciliationVolumeGuard.new(root: root))
      @user = user
      @guard = guard
      @absence = AbsentCopyPath.new(root: root)
    end

    def confirmation(ids)
      ids = Array(ids).map { |id| Integer(id.to_s, 10) }.uniq.sort
      raise ArgumentError, 'Sélectionne entre 1 et 100 copies.' unless ids.size.between?(1, 100)

      @guard.call
      assets = VideoAsset.where(id: ids).includes(:record).order(:id).to_a
      raise ArgumentError, 'Une copie sélectionnée n’existe plus.' unless assets.size == ids.size

      assets.each { |asset| validate_copy(asset) }
      plan = { 'user_id' => @user.id, 'copies' => assets.map { |asset| snapshot(asset) } }
      { assets: assets, token: verifier.generate(plan, expires_in: 15.minutes, purpose: 'missing-copy-retirement') }
    end

    def call(token)
      plan = verifier.verified(token, purpose: 'missing-copy-retirement')
      valid = plan.is_a?(Hash) && plan['user_id'] == @user.id && plan['copies'].is_a?(Array)
      raise ArgumentError, 'Confirmation expirée ou invalide.' unless valid && plan['copies'].size.between?(1, 100)

      @guard.call
      VideoAsset.transaction do
        lock_tables
        retire(plan.fetch('copies'))
      end
    end

    private

    def verifier
      Rails.application.message_verifier('missing-copy-retirement')
    end

    def snapshot(asset)
      { 'id' => asset.id, 'path' => asset.last_known_path, 'updated_at' => asset.updated_at.iso8601(9) }
    end

    def validate_copy(asset)
      unless asset.status_missing?
        raise ArgumentError,
              'Seules les copies introuvables peuvent être classées supprimées.'
      end
      raise ArgumentError, 'Une suppression vers la corbeille est déjà en cours.' if
        asset.technical_details['copy_removal_pending']

      @absence.call(asset.last_known_path)
    end

    def lock_tables
      connection = VideoAsset.connection
      return unless connection.adapter_name == 'PostgreSQL'

      connection.execute('SELECT pg_advisory_xact_lock(20261011, 1)')
      connection.execute('LOCK TABLE records IN SHARE ROW EXCLUSIVE MODE')
      connection.execute('LOCK TABLE video_assets IN SHARE ROW EXCLUSIVE MODE')
    end

    def retire(copies)
      assets = VideoAsset.where(id: copies.pluck('id')).order(:id).lock.to_a
      current = assets.map { |asset| snapshot(asset) }
      raise ArgumentError, 'La sélection a changé : renouvelle la confirmation.' unless current == copies

      assets.each { |asset| validate_copy(asset) }
      update_references(assets)
      @guard.call
      assets.each { |asset| @absence.call(asset.last_known_path) }
      assets
    end

    def update_references(assets)
      assets.each { |asset| update_reference(asset) }
    end

    def update_reference(asset)
      event = { 'origin' => 'manual_missing_confirmation', 'confirmed_at' => Time.current.iso8601(9),
                'user_id' => @user.id, 'path' => asset.last_known_path, 'previous_status' => asset.status }
      details = asset.technical_details.merge('copy_retirement' => event)
      asset.update!(status: 'deleted', technical_details: details)
    end
  end
end
