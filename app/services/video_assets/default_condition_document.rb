# frozen_string_literal: true

module VideoAssets
  # Presumption is independent of verification and never replaces a manual qualification.
  class DefaultConditionDocument
    ORIGIN = 'copy_condition_convention_v1'
    SUSPECT = /\((?:dd|d|i|début|fin)(?=[\s):–—-])[^()]*\)/

    def self.call(path, details = {})
      new(path, details).call
    end

    def self.for_asset(asset)
      result = call(asset.last_known_path, asset.condition_details || {})
      return unless result && asset.copy_condition_valid?(result)
      return if result != asset.condition_details && unexplained_record_markers?(asset)

      result
    end

    def self.unexplained_record_markers?(asset)
      record = asset.record
      return true unless record

      filename = File.basename(asset.last_known_path.to_s).scan(SUSPECT)
      [record.french_title, record.original_title].any? do |title|
        (title.to_s.scan(SUSPECT) - filename).any?
      end
    end
    private_class_method :unexplained_record_markers?

    def self.only_presumptions?(details)
      return false unless details.is_a?(Hash)

      details.values_at('integrality', 'damage') == %w[complete none] &&
        Array(details['presumed_fields']).sort == %w[damage integrality] && details['note'].blank? &&
        !details['needs_review'] && details['retained_duration_seconds'].nil? &&
        details.fetch('retained_portion', 'unknown') == 'unknown' && convention_evidence?(details)
    end

    def self.convention_evidence?(details)
      evidence = details['evidence']
      evidence.is_a?(Array) && evidence.any? && evidence.all? do |event|
        event.is_a?(Hash) && event['origin'] == ORIGIN
      end
    end
    private_class_method :convention_evidence?

    def initialize(path, details)
      @path = path.to_s
      @details = details
    end

    def call
      return if @details.is_a?(Hash) && @details['needs_review']
      return @details unless eligible?
      return if @path.blank?

      source = @details.presence || LegacyConditionMarkers.call(@path)
      return if source['needs_review'] || unrecognized_marker?

      complete_defaults(source)
    end

    private

    def eligible?
      return false unless @details.is_a?(Hash)
      return true if @details.empty?
      return false if @details['note'].present? || @details['needs_review']

      legacy_evidence?(@details['evidence'])
    end

    def legacy_evidence?(evidence)
      evidence.is_a?(Array) && evidence.any? && evidence.all? do |event|
        event.is_a?(Hash) && event['origin'] == 'legacy_filename_v1'
      end
    end

    def unrecognized_marker?
      File.basename(@path).scan(SUSPECT).any? do |marker|
        match = LegacyConditionMarkers::TOKEN.match(marker)
        !match || match[0] != marker
      end
    end

    def complete_defaults(source)
      details = source.deep_dup
      fields = []
      { 'integrality' => 'complete', 'damage' => 'none' }.each do |field, value|
        next unless [nil, 'unknown'].include?(details[field])

        details[field] = value
        fields << field
      end
      return source if fields.empty?

      add_provenance(details, fields)
    end

    def add_provenance(details, fields)
      details['retained_portion'] ||= 'unknown'
      details['needs_review'] = false
      details['presumed_fields'] = (Array(details['presumed_fields']) + fields).uniq
      event = { 'origin' => ORIGIN, 'source_path' => @path, 'fields' => fields,
                'basis' => 'Absence de signalement explicite pour ces champs ; aucune vérification du fichier.' }
      details['evidence'] = Array(details['evidence']) + [event]
      details
    end
  end
end
