# frozen_string_literal: true

module VideoAssets
  # Reassociate a manually renamed file; no filesystem/project/queue mutation.
  class CopyRelink
    attr_reader :detected_size

    def initialize(asset, user:, root: '/videos', guard: ReconciliationVolumeGuard.new(root: root))
      @asset = asset
      @user = user
      @root = root
      @guard = guard
    end

    def confirmation(path)
      raise ArgumentError, 'Copie supprimée ou suppression en cours.' if
        @asset.status_deleted? || @asset.technical_details['copy_removal_pending']

      @guard.call
      source = InventorySnapshot.new.call
      stat = stable_file(path, inventory_entry(source, path))
      @detected_size = stat.size
      plan = build_plan(path, stat, source)
      verifier.generate(plan, expires_in: 15.minutes, purpose: 'copy-relink')
    end

    def call(confirmation)
      plan = verifier.verified(confirmation, purpose: 'copy-relink')
      raise ArgumentError, 'Confirmation expirée ou invalide.' unless plan.is_a?(Hash)

      @guard.call
      VideoAsset.transaction do
        lock_tables
        @asset.reload.lock!
        validate_plan(plan)
        apply_plan(plan)
        @guard.call
      end
    end

    private

    def inventory_entry(source, path)
      review = InventoryReview.new(snapshot: source, root: @root)
      return replacement_entry(source, review) if replacement?(path)

      review.candidates(@asset).find { |item| item[:path] == path } ||
        raise(ArgumentError, 'Ce chemin n’est plus un renommage proposé par l’inventaire.')
    end

    def replacement_entry(source, review)
      check_association(@asset.last_known_path)
      if source && @asset.status_missing? && review.state(@asset) == 'changed'
        return source.fetch(:entries).find { |entry| entry[:path] == @asset.last_known_path }
      end

      raise ArgumentError, 'L’inventaire ne signale plus de fichier modifié pour cette référence.'
    end

    def replacement?(path)
      path == @asset.last_known_path
    end

    def build_plan(path, stat, source)
      { 'asset_id' => @asset.id, 'user_id' => @user.id, 'old_path' => @asset.last_known_path,
        'updated_at' => @asset.updated_at.iso8601(9), 'path' => path,
        'identity' => RelocationFileIdentity.call(stat).as_json, 'inventory_at' => source[:inventory_at] }
    end

    def apply_plan(plan)
      stat = stable_file(plan.fetch('path'))
      raise ArgumentError, 'Le fichier a changé.' unless RelocationFileIdentity.call(stat).as_json == plan['identity']

      relink(plan, stat)
    end

    def verifier
      Rails.application.message_verifier('manual-copy-relink')
    end

    def lock_tables
      connection = VideoAsset.connection
      return unless connection.adapter_name == 'PostgreSQL'

      connection.execute('SELECT pg_advisory_xact_lock(20261011, 1)')
      connection.execute('LOCK TABLE records IN SHARE ROW EXCLUSIVE MODE')
      connection.execute('LOCK TABLE video_assets IN SHARE ROW EXCLUSIVE MODE')
    end

    def validate_plan(plan)
      valid = plan.values_at('asset_id', 'user_id', 'old_path', 'updated_at') ==
              [@asset.id, @user.id, @asset.last_known_path, @asset.updated_at.iso8601(9)]
      valid &&= !@asset.status_deleted? && !@asset.technical_details['copy_removal_pending']
      raise ArgumentError, 'La copie a changé : renouvelle la confirmation.' unless valid

      check_association(plan.fetch('path'))
    end

    def check_association(path)
      candidates = VideoAsset.where(last_known_path: path)
      candidates = candidates.where(status: 'present').where.not(id: @asset.id) if replacement?(path)
      return unless candidates.exists?

      raise ArgumentError,
            'Le fichier est déjà associé à une copie.'
    end

    def stable_file(path, entry = nil)
      check_path(path)
      stat = File.lstat(path)
      valid = replacement?(path) ? stat.file? : matching_asset?(stat)
      valid &&= !entry || (entry[:size] == stat.size && Time.iso8601(entry[:modified_at]).to_i == stat.mtime.to_i)
      raise ArgumentError, 'Fichier modifié ou incompatible avec la copie.' unless valid

      stat
    end

    def check_path(path)
      valid = path.is_a?(String) && path.start_with?("#{@root}/") && Pathname.new(path).cleanpath.to_s == path
      valid &&= File.dirname(path) == File.dirname(@asset.last_known_path) && File.realpath(path) == path
      raise ArgumentError, 'Chemin non autorisé.' unless valid
    end

    def matching_asset?(stat)
      stat.file? && stat.size == @asset.byte_size && @asset.observed_at && @asset.observed_at >= stat.mtime
    end

    def relink(plan, stat)
      history = @asset.technical_details.fetch('relocation_history', [])
      event = plan.slice('identity', 'inventory_at').merge(
        'from' => plan.fetch('old_path'), 'to' => plan.fetch('path'), 'origin' => 'manual_inventory_review',
        'user_id' => @user.id, 'moved_at' => Time.current.iso8601(9)
      )
      details = @asset.technical_details.merge('relocation_history' => history + [event])
      @asset.update!(byte_size: stat.size, last_known_path: plan.fetch('path'), status: 'present',
                     observed_at: Time.current, technical_details: details)
    end
  end
end
