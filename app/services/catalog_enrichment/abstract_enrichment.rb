# frozen_string_literal: true

module CatalogEnrichment
  # Missing summaries may be filled; editorial text requires an explicit edit through the record form.
  class AbstractEnrichment
    def initialize(record:, text:, source:, identity_confirmed: false)
      raise ArgumentError, 'Summary must be text and source must be an object' unless
        (text.nil? || text.is_a?(String)) && source.is_a?(Hash)

      @record = record
      @text = text
      @source = source.deep_stringify_keys
      @identity_confirmed = identity_confirmed
    end

    def call(apply: false)
      return report(decision, false) unless apply

      @record.with_lock do
        status = decision
        @record.save_external_abstract!(@text, source: @source) if status == 'candidate'
        report(status == 'candidate' ? 'applied' : status, status == 'candidate')
      end
    end

    private

    def decision
      return 'no_candidate' if @text.blank?
      return 'needs_review' unless confirmed_source?
      return 'unchanged' if @record.abstract == @text
      return 'protected' if @record.abstract_protected?
      return 'source_changed' unless same_source?

      'candidate'
    end

    def confirmed_source?
      @identity_confirmed == true && @source['provider'].present? && @source['external_id'].present?
    end

    def same_source?
      return true unless @record.abstract_provenance['kind'] == 'external'

      previous = @record.abstract_provenance.fetch('source', {})
      previous.slice('provider', 'external_id') == @source.slice('provider', 'external_id')
    end

    def report(status, applied)
      { status: status, applied: applied, record_id: @record.id,
        current_text: @record.abstract, proposed_text: @text, source: @source,
        editorial_validation_required: %w[needs_review protected source_changed].include?(status) }
    end
  end
end
