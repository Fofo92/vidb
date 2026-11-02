# frozen_string_literal: true

module VideoAssets
  # The pending plan is committed before the move, allowing a failed request to resume.
  class CopyRemoval
    class Error < StandardError; end

    def initialize(asset, user:, bridge: CopyRemovalBridge.new)
      @asset = asset
      @user = user
      @bridge = bridge
    end

    def confirmation
      plan = @asset.technical_details['copy_removal_pending'] || preview
      verifier.generate(plan, expires_in: 30.minutes, purpose: 'copy-removal')
    end

    def call(confirmation)
      plan = verifier.verified(confirmation, purpose: 'copy-removal')
      raise Error, 'Confirmation expirée ou invalide : ouvre à nouveau la confirmation.' unless valid?(plan)

      prepare(plan)
      return if @asset.reload.status_deleted?

      receipt = @bridge.call(plan.fetch('request').merge('operation' => 'remove'))
      finish(plan, receipt)
    end

    private

    def verifier
      Rails.application.message_verifier('confirmed-copy-removal')
    end

    def preview
      raise Error, 'Cette copie n’est plus présente.' unless @asset.status_present?

      request = @bridge.call('operation' => 'preview', 'path' => @asset.last_known_path)
      { 'asset_id' => @asset.id, 'user_id' => @user.id, 'path' => @asset.last_known_path,
        'request' => request.merge('id' => SecureRandom.uuid) }
    end

    def valid?(plan)
      plan.is_a?(Hash) && plan['asset_id'] == @asset.id && plan['user_id'] == @user.id &&
        plan['path'] == @asset.last_known_path && plan['request'].is_a?(Hash)
    end

    def prepare(plan)
      @asset.with_lock do
        raise Error, 'La copie a changé : renouvelle la confirmation.' unless valid?(plan)
        next if @asset.status_deleted?

        details = @asset.technical_details.deep_dup
        validate_pending(details['copy_removal_pending'], plan)

        details['copy_removal_pending'] = plan
        @asset.update!(technical_details: details)
      end
    end

    def validate_pending(pending, plan)
      raise Error, 'Une autre suppression est déjà préparée : renouvelle la confirmation.' if pending && pending != plan
      raise Error, 'Cette copie n’est plus présente.' unless @asset.status_present? || pending
    end

    def finish(plan, receipt)
      validate_receipt(plan, receipt)
      @asset.with_lock do
        next if @asset.status_deleted?

        details = @asset.technical_details.deep_dup
        raise Error, 'La suppression a changé : vérification nécessaire.' unless
          valid?(plan) && details['copy_removal_pending'] == plan

        details.delete('copy_removal_pending')
        details['copy_removal'] = receipt.merge('user_id' => @user.id, 'removed_at' => Time.current.iso8601)
        @asset.update!(status: 'deleted', technical_details: details)
      end
    end

    def validate_receipt(plan, receipt)
      expected = plan.fetch('request')
      return if receipt['path'] == plan['path'] && receipt['id'] == expected['id'] && receipt['directory'].is_a?(String)

      raise Error, 'Réponse de corbeille incohérente : la suppression reste à vérifier.'
    end
  end
end
