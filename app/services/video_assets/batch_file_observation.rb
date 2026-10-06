# frozen_string_literal: true

module VideoAssets
  class BatchFileObservation
    def call(entry)
      path = entry.fetch(:path)
      before = File.lstat(path)
      validate_snapshot!(entry, before)
      measured = CatalogEnrichment::TechnicalObservation.new.call(path)
      after = File.lstat(path)
      raise ArgumentError, "File changed during observation: #{path}" unless identity(before) == identity(after)

      measured.merge(file_identity: identity(after))
    end

    def verify!(observed)
      path = observed.fetch(:path)
      return if identity(File.lstat(path)) == observed.fetch(:file_identity)

      raise ArgumentError, "File changed before import: #{path}"
    end

    private

    def validate_snapshot!(entry, stat)
      valid = stat.file? && stat.size == entry.fetch(:size) && stat.mtime.iso8601 == entry.fetch(:modified_at)
      raise ArgumentError, "File differs from inventory: #{entry.fetch(:path)}" unless valid
    end

    def identity(stat)
      [stat.dev, stat.ino, stat.size, stat.mtime.to_f, stat.ctime.to_f]
    end
  end
end
