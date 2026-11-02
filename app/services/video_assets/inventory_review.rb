# frozen_string_literal: true

module VideoAssets
  class InventoryReview
    def initialize(snapshot:, assets: VideoAsset.where(status: %w[present missing]), root: '/videos')
      @snapshot = snapshot
      @assets = assets.to_a
      @root = root
      @entries = (snapshot&.fetch(:entries, []) || []).index_by { |entry| entry[:path] }
      @by_size = @entries.values.group_by { |entry| entry[:size] }
      @known = @assets.to_set(&:last_known_path)
    end

    def call
      return [] unless @snapshot

      @assets.filter_map do |asset|
        status = state(asset)
        next if status == 'confirmed'

        { asset: asset, status: status, candidates: candidates(asset) }
      end
    end

    def state(asset)
      return 'outside' unless canonical?(asset.last_known_path)

      entry = @entries[asset.last_known_path]
      return 'absent' unless entry
      return 'unverified' unless asset.byte_size && asset.observed_at
      return 'changed' unless asset.byte_size == entry[:size] && asset.observed_at >= Time.iso8601(entry[:modified_at])

      'confirmed'
    end

    def candidates(asset)
      return [] unless %w[absent changed].include?(state(asset)) && asset.byte_size && asset.observed_at

      matches = (@by_size[asset.byte_size] || []).select { |entry| candidate?(asset, entry) }
      matches.sort_by { |entry| [rename_rank(asset, entry), entry[:path]] }
    end

    private

    def candidate?(asset, entry)
      path = entry[:path]
      canonical?(path) && !@known.include?(path) && File.dirname(path) == File.dirname(asset.last_known_path) &&
        Time.iso8601(entry[:modified_at]) <= asset.observed_at
    end

    def rename_rank(asset, entry)
      original = File.basename(asset.last_known_path, '.*')
      candidate = File.basename(entry[:path], '.*')
      preferred = %w[old vf].any? { |suffix| candidate.casecmp?("#{original}_#{suffix}") }
      preferred && File.extname(entry[:path]).casecmp?(File.extname(asset.last_known_path)) ? 0 : 1
    end

    def canonical?(path)
      path.is_a?(String) && path.start_with?("#{@root}/") && Pathname.new(path).cleanpath.to_s == path &&
        %w[.mkv .m4v .avi].include?(File.extname(path).downcase)
    end
  end
end
