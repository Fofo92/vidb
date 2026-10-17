require 'digest'

module ReconciliationWorkbench
  module Snapshot
    def self.record(record)
      attributes = record.attributes.transform_values do |value|
        value.respond_to?(:iso8601) ? value.iso8601(9) : value
      end
      { 'attributes' => attributes, 'genres' => record.genders.order(:id).pluck(:id),
        'countries' => record.countries.order(:id).pluck(:id), 'media' => record.media.order(:id).pluck(:id),
        'children' => record.children.order(:id).pluck(:id, :record_kind, :rank, :ancestry, :french_title) }
    end

    def self.canonical(value)
      case value
      when Hash then value.stringify_keys.sort.to_h.transform_values { |item| canonical(item) }
      when Array then value.map { |item| canonical(item) }
      else value
      end
    end

    def self.digest(value)
      Digest::SHA256.hexdigest(JSON.generate(canonical(value)))
    end

    def self.known_transition?(id, original, current)
      cursor = original
      ReconciliationRecordChange.where(record_id: id).order(:id).each do |change|
        next unless change.before_digest == cursor && digest(change.after_snapshot) == change.after_digest

        cursor = change.after_digest
        return true if cursor == current
      end
      false
    end

    def self.verify!(expected)
      expected.each do |id, state|
        record = Record.lock.find(id)
        current = digest(record(record))
        original = digest(state)
        next if current == original || known_transition?(id, original, current)

        raise ArgumentError, "Fiche ##{id} modifiée depuis la proposition"
      end
    end
  end
end
