# frozen_string_literal: true

require 'time'

module VideoAssets
  # Imports an explicit montage declaration only when attaching its finished copy.
  class ExportCondition
    def self.call(receipt)
      return {} unless receipt.key?('copy_condition')

      new(receipt.fetch('copy_condition')).call
    end

    def initialize(declaration)
      @declaration = declaration
    end

    def call
      validate!
      values = @declaration.slice('integrality', 'damage', 'retained_portion', 'note')
      event = { 'origin' => 'video_encoder_montage', 'at' => @declaration.fetch('declared_at'),
                'source_paths' => @declaration.fetch('source_paths'),
                'affected_source_paths' => @declaration.fetch('affected_source_paths') }
      { condition_details: values.merge('needs_review' => false, 'evidence' => [event]) }
    end

    private

    def validate!
      valid = @declaration.is_a?(Hash) && valid_values? && valid_sources? && valid_date?
      raise ArgumentError, 'Déclaration d’état du montage invalide' unless valid
    end

    def valid_values?
      value = @declaration
      %w[complete incomplete].include?(value['integrality']) && %w[none light severe].include?(value['damage']) &&
        valid_portion? &&
        value['note'].is_a?(String) && value['note'].length <= 2000
    end

    def valid_portion?
      portion = @declaration['retained_portion']
      %w[unknown beginning end].include?(portion) &&
        (@declaration['integrality'] == 'incomplete' || portion == 'unknown')
    end

    def valid_sources?
      paths = @declaration['source_paths']
      affected = @declaration['affected_source_paths']
      [paths, affected].all? { |items| valid_paths?(items) } && (affected - paths).empty?
    end

    def valid_paths?(items)
      items.is_a?(Array) && items.size <= 100 && items.all? do |path|
        path.is_a?(String) && path.start_with?('/') && !path.include?("\0")
      end
    end

    def valid_date?
      value = @declaration['declared_at']
      value.is_a?(String) && value.match?(/(?:Z|[+-]\d{2}:\d{2})\z/) && Time.iso8601(value)
    rescue ArgumentError
      false
    end
  end
end
