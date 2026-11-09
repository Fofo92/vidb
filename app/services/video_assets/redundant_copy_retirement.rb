# frozen_string_literal: true

module VideoAssets
  # Runs inside the complete inventory transaction and its catalogue locks.
  class RedundantCopyRetirement
    def initialize(root:, backup:)
      @absence = AbsentCopyPath.new(root: root)
      @backup = backup
    end

    def call(present, absent, &)
      replacements = present.index_by { |asset| copy_key(asset) }
      redundant = absent.select { |asset| replacements.key?(copy_key(asset)) && safely_absent?(asset.last_known_path) }
      redundant.each_slice(100) { |assets| retire(assets, replacements, &) }
      redundant.size
    end

    private

    def copy_key(asset)
      [asset.record_id, asset.broadcast_part_number, File.basename(asset.last_known_path)]
    end

    def safely_absent?(path)
      @absence.call(path)
    rescue ArgumentError
      false
    end

    def retire(assets, replacements)
      @backup.write(assets, user: nil)
      assets.each do |asset|
        replacement = replacements.fetch(copy_key(asset))
        raise ArgumentError, 'La copie restante a changé pendant le contrôle.' unless yield(replacement)

        @absence.call(asset.last_known_path)
        asset.destroy!
      end
    end
  end
end
