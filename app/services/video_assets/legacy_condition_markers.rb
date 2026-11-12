# frozen_string_literal: true

module VideoAssets
  # Interpret only Pascal's explicit lowercase markers, never directory names or Roman numerals.
  class LegacyConditionMarkers
    TOKEN = /\((dd|d|i|début\s+[^()]+|fin\s+[^()]+)\)/

    def self.call(path)
      new(path).call
    end

    def initialize(path)
      @path = path.to_s
      @name = File.basename(@path)
    end

    def call
      tokens = @name.scan(TOKEN).flatten
      return {} if tokens.empty?

      document(tokens)
    end

    private

    def document(tokens)
      portions = tokens.filter_map { |token| portion(token) }
      review = review_needed?(portions)
      selected = portions.first unless review
      { 'integrality' => tokens.include?('i') || portions.any? ? 'incomplete' : 'unknown',
        'damage' => damage(tokens), 'retained_portion' => selected ? selected[:part] : 'unknown',
        'retained_duration_seconds' => selected && selected[:seconds], 'needs_review' => review,
        'evidence' => [{ 'origin' => 'legacy_filename_v1', 'source_path' => @path,
                         'markers' => tokens.map { |token| "(#{token})" } }] }
    end

    def review_needed?(portions)
      portions.any? { |item| item[:seconds].nil? } ||
        portions.map { |item| item.values_at(:part, :seconds) }.uniq.size > 1
    end

    def damage(tokens)
      return 'severe' if tokens.include?('dd')
      return 'light' if tokens.include?('d')

      'unknown'
    end

    def portion(token)
      match = token.match(/\A(début|fin)\s+(.+)\z/)
      return unless match

      { part: match[1] == 'début' ? 'beginning' : 'end',
        seconds: RetainedDuration.parse(match[2]) }
    end
  end
end
