# frozen_string_literal: true

module VideoAssets
  # Runs inside the complete inventory transaction and its catalogue locks.
  class RedundantCopyRetirement
    def initialize(root:, backup:)
      @absence = AbsentCopyPath.new(root: root)
      @backup = backup
    end

    def call(present, absent, &)
      by_path = present.index_by(&:last_known_path)
      by_name = present.index_by { |asset| copy_key(asset) }
      redundant = absent.filter_map do |asset|
        replacement = replacement_for(asset, by_path, by_name)
        [asset, replacement] if replacement
      end
      redundant.each_slice(100) { |pairs| retire(pairs, &) }
      redundant.size
    end

    private

    def replacement_for(asset, by_path, by_name)
      # A qualified copy carries information that must survive reconciliation.
      return if asset.condition_details.present?

      same_path = by_path[asset.last_known_path]
      return same_path if same_path && copy_key(same_path) == copy_key(asset)

      replacement = by_name[copy_key(asset)]
      replacement if replacement && safely_absent?(asset.last_known_path)
    end

    def copy_key(asset)
      [asset.record_id, asset.broadcast_part_number, File.basename(asset.last_known_path)]
    end

    def safely_absent?(path)
      @absence.call(path)
    rescue ArgumentError
      false
    end

    def retire(pairs)
      @backup.write(pairs.map(&:first), user: nil)
      pairs.each do |asset, replacement|
        raise ArgumentError, 'La copie restante a changé pendant le contrôle.' unless yield(replacement)

        @absence.call(asset.last_known_path) unless asset.last_known_path == replacement.last_known_path
        asset.destroy!
      end
    end
  end
end
