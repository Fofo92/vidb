module Tv
  class CaptureEpisodeIndex
    EXTENSIONS = %w[.m2t .mts .ts].freeze
    NUMBER = /\A(.+?)\s*[-–—]\s*S(?:aison)?\s*(\d{1,2})\s*[,;:–—-]?
              \s*[EÉé](?:pisode)?\s*(\d{1,3})(?:\s*[-–—:]\s*(.*))?\z/ix

    def initialize(capture_roots: nil, quarantine_roots: nil, cache: Rails.cache)
      @capture_roots = capture_roots || roots('VIDB_TV_CAPTURE_ROOTS', '/commun/to_be_cut')
      @quarantine_roots = quarantine_roots || roots('VIDB_TV_QUARANTINE_ROOTS', '/commun/Quarantaine')
      @cache = cache
    end

    def call
      key = ['tv-capture-work-index-v2', @capture_roots, @quarantine_roots]
      @cache.fetch(key, expires_in: 1.minute) do
        scan(@capture_roots, 'capture') + scan(@quarantine_roots, 'quarantine')
      end
    end

    private

    def roots(variable, default)
      ENV.fetch(variable, default).split(File::PATH_SEPARATOR).select { |path| path.start_with?('/') }.uniq
    end

    def scan(roots, kind)
      roots.flat_map do |root|
        Dir.glob(File.join(root, '**', '*')).filter_map { |path| entry(path, kind) }
      rescue SystemCallError
        []
      end
    end

    def entry(path, kind)
      return unless EXTENSIONS.include?(File.extname(path).downcase)

      identity = file_identity(File.basename(path, File.extname(path)))
      return unless identity

      stat = File.lstat(path)
      return unless stat.file? && stat.size.positive?

      identity.merge(path: path, kind: kind)
    rescue SystemCallError
      nil
    end

    def file_identity(stem)
      match = NUMBER.match(stem)
      return episode_identity(match) if match
      return if stem.match?(/\bS(?:aison)?\s*\d|\b[EÉé]pisode\s*\d/i)

      title = AcquiredEpisodeIdentity.normalize(stem)
      { key: title, title: title } if title.present?
    end

    def episode_identity(match)
      return unless match[3].to_i.positive?
      return if match[4].to_s.match?(/\b(?:S\d+\s*)?E\d+\b/i)

      { key: [AcquiredEpisodeIdentity.normalize(match[1]), match[2].to_i, match[3].to_i],
        title: AcquiredEpisodeIdentity.normalize(match[4]) }
    end
  end
end
