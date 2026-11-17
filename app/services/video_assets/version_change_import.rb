# frozen_string_literal: true

module VideoAssets
  # Burned subtitles are a visual user declaration, never inferred from absent subtitle streams.
  class VersionChangeImport
    def self.language(details, receipt)
      declaration = receipt['version_change']
      return unless declaration

      raise ArgumentError, 'Déclaration VOST incompatible avec les pistes finales.' unless
        valid?(details.fetch('streams'), receipt, declaration)

      'VOST'
    end

    def self.valid?(streams, receipt, declaration)
      valid_declaration?(declaration) && receipt['roles'] == ['original'] &&
        streams.one? { |row| row['codec_type'] == 'audio' } &&
        streams.none? { |row| row['codec_type'] == 'subtitle' }
    end

    def self.valid_declaration?(declaration)
      declaration.is_a?(Hash) && declaration['profile'] == 'VOST' &&
        declaration['original_confirmed'] == true && declaration['burned_french_confirmed'] == true
    end

    def self.condition(record, receipt)
      path = receipt.dig('version_change', 'source_path')
      return {} unless path

      source = record.video_assets.find_by(last_known_path: path)
      source ? { condition_details: source.condition_details.deep_dup } : {}
    end
  end
end
