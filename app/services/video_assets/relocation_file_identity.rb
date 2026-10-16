# frozen_string_literal: true

module VideoAssets
  module RelocationFileIdentity
    def self.call(stat)
      { dev: stat.dev, ino: stat.ino, size: stat.size,
        mtime_ns: (stat.mtime.to_r * 1_000_000_000).to_i,
        ctime_ns: (stat.ctime.to_r * 1_000_000_000).to_i }
    end

    def self.signature(stat)
      [stat.dev, stat.ino, stat.size, stat.mtime.to_r, stat.ctime.to_r]
    end
  end
end
