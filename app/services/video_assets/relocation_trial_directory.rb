# frozen_string_literal: true

module VideoAssets
  class RelocationTrialDirectory
    attr_reader :root

    def initialize(root, error:)
      @root = Pathname.new(root).cleanpath
      @error = error
    end

    def validate!
      raise @error, 'A private /tmp/vidb-relocation-* directory is required' unless trial_path?

      validate_stat!(File.lstat(root))
    end

    def validate_stat!(stat)
      return if stat.directory? && stat.uid == Process.uid && stat.mode.nobits?(0o077)

      raise @error, 'Trial directory must be private and owned by the current user'
    end

    def direct_path?(path)
      path.absolute? && path == path.cleanpath && path.dirname == root && !path.to_s.include?("\0")
    end

    private

    def trial_path?
      root.absolute? && root.dirname.to_s == '/tmp' && root.basename.to_s.start_with?('vidb-relocation-')
    end
  end
end
