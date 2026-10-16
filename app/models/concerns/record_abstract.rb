# frozen_string_literal: true

require 'digest'

module RecordAbstract
  extend ActiveSupport::Concern

  included do
    before_save :track_abstract_provenance
  end

  def abstract_protected?
    return true if abstract_provenance['kind'] == 'manual'
    return abstract.present? unless abstract_provenance['kind'] == 'external'

    abstract_provenance['content_sha256'] != abstract_digest
  end

  # Only the enrichment service supplies this context, after checking identity and taking the row lock.
  def save_external_abstract!(text, source:)
    with_lock do
      raise ArgumentError, 'Protected abstract requires an explicit editorial edit' if abstract_protected?

      @external_abstract_source = source.deep_dup
      update!(abstract: text)
    end
  ensure
    @external_abstract_source = nil
  end

  private

  def abstract_digest
    Digest::SHA256.hexdigest(abstract.to_s)
  end

  def track_abstract_provenance
    return unless will_save_change_to_abstract? && (abstract.present? || abstract_in_database.present?)

    self.abstract_provenance = {
      'kind' => @external_abstract_source ? 'external' : 'manual',
      'changed_at' => Time.current.iso8601, 'content_sha256' => abstract_digest
    }
    abstract_provenance['source'] = @external_abstract_source if @external_abstract_source
  end
end
