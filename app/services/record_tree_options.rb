# frozen_string_literal: true

class RecordTreeOptions
  def call(selected_id: nil)
    records = Record.select(:id, :ancestry, :french_title, :original_title).to_a
    @by_id = records.index_by(&:id)
    parents = records.filter_map { |record| ancestor_ids(record).last }.to_set
    parents << selected_id.to_i if selected_id.present?
    records.select { |record| parents.include?(record.id) }.map { |record| [label(record), record.id] }.sort
  end

  private

  def ancestor_ids(record)
    record.ancestry.to_s.split("/").reject(&:empty?).map(&:to_i)
  end

  def label(record)
    titles = ancestor_ids(record).filter_map { |id| @by_id[id]&.complete_title }
    "#{(titles + [record.complete_title]).join(' / ')} — ##{record.id}"
  end
end
