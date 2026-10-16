# frozen_string_literal: true

module VideoAssets
  class RelocationFileObservation
    def call(path, expected, renamed:)
      stat = File.lstat(path)
      { path: path, state: state_for(stat),
        identity_matches: stat.file? && identity_matches?(stat, expected, renamed: renamed) }
    rescue Errno::ENOENT
      { path: path, state: :missing, identity_matches: false }
    rescue SystemCallError => e
      { path: path, state: :unreadable, identity_matches: false, error_class: e.class.name }
    end

    private

    def state_for(stat)
      return :symlink if stat.symlink?

      stat.file? ? :regular : :not_regular
    end

    def identity_matches?(stat, expected, renamed:)
      actual = RelocationFileIdentity.call(stat).stringify_keys
      keys = RelocationTrialJournalFormat::IDENTITY_KEYS
      keys -= ['ctime_ns'] if renamed
      keys.all? { |key| actual[key] == expected[key] }
    end
  end
end
