# frozen_string_literal: true

module VideoAssets
  class RelocationFileRename
    def initialize(native: RelocationNativeRename.new)
      @native = native
    end

    def call(source:, target:, identity:)
      source, target = checked_paths(source, target)
      RelocationDirectoryHandle.new.call(source.dirname) do |directory|
        rename_from(directory, source, target, identity)
        directory.fsync
        verify_target!(directory, target, identity)
      end
    end

    private

    def checked_paths(source, target)
      paths = [source, target].map { |path| Pathname.new(path) }
      valid = paths.all? { |path| path.absolute? && path == path.cleanpath } &&
              paths.first.dirname == paths.last.dirname && paths.first != paths.last
      raise ArgumentError, 'Distinct canonical files in the same directory are required' unless valid

      paths
    end

    def rename_from(directory, source, target, identity)
      anchored = "/proc/self/fd/#{directory.fileno}/#{source.basename}"
      File.open(anchored, File::RDONLY | File::NOFOLLOW | File::NONBLOCK) do |file|
        stat = file.stat
        unless stat.file? && RelocationFileIdentity.call(stat) == identity
          raise ArgumentError,
                'Source identity changed'
        end

        @native.call(directory.fileno, source.basename.to_s, target.basename.to_s)
      end
    end

    def verify_target!(directory, target, identity)
      anchored = File.lstat("/proc/self/fd/#{directory.fileno}/#{target.basename}")
      visible = File.lstat(target)
      expected = identity.except(:ctime_ns)
      matches = [anchored, visible].all? do |stat|
        stat.file? && RelocationFileIdentity.call(stat).except(:ctime_ns) == expected
      end
      raise ArgumentError, 'Target identity or visible directory changed after rename' unless matches
    end
  end
end
