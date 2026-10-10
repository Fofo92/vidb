# frozen_string_literal: true

module RecordMetadata
  extend ActiveSupport::Concern

  def metadata_container?
    %w[series season].include?(record_kind)
  end

  def effective_countries
    RecordMetadataValues.new(record: self).countries
  end

  def effective_genders
    RecordMetadataValues.new(record: self).genders
  end
end
