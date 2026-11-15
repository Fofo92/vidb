# frozen_string_literal: true

# Physical ownership is independent of encoded files and viewing/recording states.
class DvdOwnership
  def self.confirm!(edition:, record:)
    edition.with_lock do
      unless edition.record.subtree.exists?(id: record.id)
        raise ArgumentError, "Cette œuvre n’appartient pas à la série de cette édition DVD."
      end

      content = edition.dvd_contents.find_or_create_by!(record: record)
      mark_support!(record)
      content
    end
  end

  def self.mark_support!(record)
    record.with_lock do
      medium = Medium.find_or_create_by!(short_name: 'DVD') { |item| item.long_name = 'DVD' }
      record.media << medium unless record.media.exists?(medium.id)
    end
  end
end
