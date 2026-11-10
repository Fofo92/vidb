# frozen_string_literal: true

class RecordMetadataModeUpdate
  INVALID_VALUES = {
    genders: 'choisis un ou deux genres connus sur la série ou la collection, ou désactive la règle',
    countries: 'choisis au moins un pays connu sur la série ou la collection, ou désactive la règle'
  }.freeze

  def initialize(record, attributes:)
    @record = record
    @attributes = attributes
  end

  def call
    @record.with_lock(requires_new: true) do
      @record.assign_attributes(@attributes)
      raise ActiveRecord::Rollback unless valid_modes? && @record.save

      true
    end
  end

  private

  def valid_modes?
    metadata = RecordMetadataValues.new(records: [@record])
    RecordMetadataValues::MODE_ATTRIBUTES.each do |field, attribute|
      mode = @record.public_send(attribute)
      next if valid_mode?(metadata, field, mode)

      @record.errors.add(attribute, INVALID_VALUES.fetch(field))
    end
    @record.errors.empty?
  end

  def valid_mode?(metadata, field, mode)
    return true if mode == 'current'
    return false unless RecordMetadataValues.forcing_root?(@record) && RecordMetadataValues::MODES.key?(mode)
    return true if mode == 'add'

    RecordMetadataValues.forceable?(field, metadata.explicit(@record, field).uniq(&:id))
  end
end
