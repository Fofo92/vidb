# frozen_string_literal: true

module VideoAssets
  # Interpret only Pascal's explicit lowercase markers, never directory names or Roman numerals.
  class LegacyConditionMarkers
    TOKEN = /\((dd|d|i|début\s+[^()]+|fin\s+[^()]+)\)/
    MINUTES = /\A(\d+)\s*(?:['’′]|min(?:utes?)?|mn)\z/

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

      duration = match[2].match(MINUTES)
      minutes = duration && Integer(duration[1], 10)
      { part: match[1] == 'début' ? 'beginning' : 'end',
        seconds: minutes&.positive? && minutes <= 1440 ? minutes * 60 : nil }
    end
  end
end
