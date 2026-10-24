# frozen_string_literal: true

require 'stringio'

module RecordPosters
  class Store
    class Error < StandardError; end

    def self.call(record, bytes:, source:, automatic: false, restore: false)
      blob = image_attributes(bytes)
      poster = RecordPoster.create_or_find_by!(record_id: record.id)
      record.association(:record_poster).reset
      poster.with_lock do
        return :preserved if automatic && (poster.image.attached? || (poster.source['kind'] == 'manual' && !restore))

        poster.update!(source: source, image: blob)
      end
      :attached
    end

    def self.image_attributes(bytes)
      raise Error, 'Pochette vide ou supérieure à 5 Mo' unless bytes.bytesize.between?(1, RecordPoster::MAX_BYTES)

      type = Marcel::MimeType.for(StringIO.new(bytes))
      raise Error, 'Utilise une image JPEG, PNG ou WebP' unless RecordPoster::CONTENT_TYPES.include?(type)

      extension = { 'image/jpeg' => 'jpg', 'image/png' => 'png', 'image/webp' => 'webp' }.fetch(type)
      { io: StringIO.new(bytes), filename: "pochette.#{extension}", content_type: type,
        metadata: { analyzed: true } }
    end
  end
end
