# frozen_string_literal: true

require 'fiddle'

module VideoAssets
  # Experimental executor for private /tmp/vidb-relocation-* fixtures only.
  # No database writes. Not intended for /videos or concurrent writers.
  class RelocationTrialExecutor
    class Refused < StandardError; end
    class Unsupported < StandardError; end

    def initialize(root:, planner:, renamer: nil)
      @directory = RelocationTrialDirectory.new(root, error: Refused)
      @root = @directory.root
      @planner = planner
      @renamer = renamer || method(:rename_without_replace)
    end

    def call(plan:, asset:, genres:)
      @directory.validate!
      current = checked_preview(plan, asset, genres)
      source, target = checked_paths(current)
      perform_rename(source, target, current.fetch(:identity))
      { status: :renamed, source: source.to_s, target: target.to_s, database_updated: false }
    end

    private

    def checked_preview(plan, asset, genres)
      raise Refused, 'Initial preview is not ready' unless plan[:ready] == true

      current = @planner.recheck(plan: plan, asset: asset, genres: genres)
      raise Refused, 'Preview no longer matches' unless current[:ready] == true

      current
    end

    def checked_paths(current)
      source = Pathname.new(current.fetch(:source))
      target = Pathname.new(current.fetch(:target))
      unless @directory.direct_path?(source) && @directory.direct_path?(target) && source != target
        raise Refused, 'Only files directly inside the trial root are allowed'
      end

      [source, target]
    end

    def perform_rename(source, target, identity)
      File.open(@root, File::RDONLY | File::NOFOLLOW) do |directory|
        @directory.validate_stat!(directory.stat)
        rename_from(directory, source, target, identity)
      end
    end

    def rename_from(directory, source, target, identity)
      anchored_source = "/proc/self/fd/#{directory.fileno}/#{source.basename}"
      File.open(anchored_source, File::RDONLY | File::NOFOLLOW) do |file|
        stat = file.stat
        raise Refused, 'Source identity changed' unless stat.file? && RelocationFileIdentity.call(stat) == identity

        @renamer.call(directory.fileno, source.basename.to_s, target.basename.to_s)
      end
    end

    def rename_without_replace(directory_fd, source, target)
      # Linux renameat2(..., RENAME_NOREPLACE): atomic refusal on collision.
      # Never fall back to File.rename, which may overwrite the destination.
      function = Fiddle::Function.new(
        Fiddle::Handle::DEFAULT['renameat2'],
        [Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT, Fiddle::TYPE_VOIDP, Fiddle::TYPE_INT],
        Fiddle::TYPE_INT
      )
      result = function.call(directory_fd, source, directory_fd, target, 1)
      raise SystemCallError.new('renameat2 RENAME_NOREPLACE', Fiddle.last_error) unless result.zero?
    rescue Fiddle::DLError
      raise Unsupported, 'renameat2 is unavailable; no fallback rename was attempted'
    end
  end
end
