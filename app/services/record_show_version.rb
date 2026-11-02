# frozen_string_literal: true

require 'digest'

# Fingerprint the visible tree and its associations, including changes that do not touch Record.
class RecordShowVersion
  def initialize(record)
    @scope = record.root.subtree.reorder(:id)
  end

  def call
    Record.uncached do
      data = ['record-show-v1', @scope.pluck(*Record.column_names), qualifications, copies, posters, references]
      Digest::SHA256.hexdigest(ActiveSupport::JSON.encode(data))
    end
  end

  private

  def qualifications
    [[:countries, Country], [:genders, Gender], [:media, Medium]].map do |association, model|
      keys = [Record.arel_table[:id], model.arel_table[:id]]
      @scope.joins(association).reorder(*keys).pluck(*keys)
    end
  end

  def copies
    VideoAsset.where(record_id: @scope.select(:id)).order(:id).pluck(*VideoAsset.column_names)
  end

  def posters
    owners = RecordPoster.where(record_id: @scope.select(:id))
    images = ActiveStorage::Attachment.where(record_type: 'RecordPoster', record_id: owners.select(:id), name: 'image')
    [owners.order(:id).pluck(*RecordPoster.column_names), images.order(:id).pluck(:id, :record_id, :blob_id)]
  end

  def references
    [Country, Gender, Medium, LanguageVersion].map { |model| model.order(:id).pluck(*model.column_names) }
  end
end
