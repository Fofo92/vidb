# frozen_string_literal: true

module VideoAssets
  class ReclassificationReceipt
    def self.verify!(record:, qualification:, classification:)
      expected = { 'origin' => 'documented_review', 'protected' => true,
                   'operation_id' => qualification.fetch(:operation_id), 'genres' => classification.fetch(:genres),
                   'previous_genres' => qualification.dig(:expected, :genres),
                   'evidence' => qualification.fetch(:evidence).deep_stringify_keys }
      valid = record.genre_provenance.except('recorded_at') == expected &&
              record.genders.reload.map(&:name).sort == expected['genres']
      raise RelocationCommit::Refused, 'Genre receipt changed after commit' unless valid
    end
  end
end
