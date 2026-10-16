# frozen_string_literal: true

module VideoAssets
  class RelocationPathBuilder
    def initialize(root: '/videos')
      @root = Pathname.new(root)
    end

    def call(record:, genres:)
      raise ArgumentError, 'Only standalone films' unless record.record_kind_standalone_video?
      raise ArgumentError, 'One or two genres required' unless genres.size.between?(1, 2)
      raise ArgumentError, 'Missing title or year' if record.french_title.blank? || record.year.blank?

      genres = genres.map { |value| safe(value) }.sort
      title = safe(record.french_title)
      original = record.original_title.present? ? " (#{safe(record.original_title)})" : ''
      prefix = record.is_seen? ? '[*] ' : ''
      @root.join('Films', genres.join(', '), "#{prefix}#{title}#{original} (#{record.year}).mkv").to_s
    end

    private

    def safe(value)
      s = value.to_s.strip
      raise ArgumentError, 'Unsafe path component' if s.empty? || %w[. ..].include?(s) || s.match?(%r{[/\\\x00-\x1f]})

      s
    end
  end
end
