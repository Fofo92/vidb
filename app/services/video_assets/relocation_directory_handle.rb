# frozen_string_literal: true

module VideoAssets
  # Walk every directory through pinned descriptors, refusing symbolic links.
  class RelocationDirectoryHandle
    def call(path, &)
      path = Pathname.new(path)
      raise ArgumentError, 'An absolute canonical directory is required' unless path.absolute? && path == path.cleanpath

      File.open('/', flags) { |root| descend(root, path.each_filename.to_a, &) }
    end

    private

    def flags
      File::RDONLY | File::NOFOLLOW | File::NONBLOCK
    end

    def descend(directory, components, &)
      raise ArgumentError, 'Not a directory' unless directory.stat.directory?
      return yield directory if components.empty?

      path = "/proc/self/fd/#{directory.fileno}/#{components.first}"
      File.open(path, flags) { |child| descend(child, components.drop(1), &) }
    end
  end
end
