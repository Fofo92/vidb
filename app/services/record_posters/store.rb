# frozen_string_literal: true

require 'stringio'

module RecordPosters
  class Store
    class Error < StandardError; end

    # The expected refresh reference is checked again under the poster row lock.
    def self.call(record, bytes:, source:, automatic: false, restore: false, refresh: nil) # rubocop:disable Metrics/ParameterLists
      blob = image_attributes(bytes)
      poster = RecordPoster.create_or_find_by!(record_id: record.id)
      record.association(:record_poster).reset
      poster.with_lock do
        return :preserved if automatic && protected?(poster, restore, refresh)

        poster.update!(source: source, image: blob)
      end
      :attached
    end

    def self.protected?(poster, restore, refresh)
      return true if poster.source['kind'] == 'manual' && (!restore || poster.image.attached?)
      return true if stale_refresh?(poster, refresh)
      return false unless poster.image.attached?

      !(poster.source['kind'] == 'tmdb' && refresh.is_a?(Hash) && poster.source['encoder_pending'] == refresh)
    end
    private_class_method :protected?

    def self.stale_refresh?(poster, refresh)
      pending = poster.source['encoder_pending']
      pending.is_a?(Hash) && pending != refresh
    end
    private_class_method :stale_refresh?

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
