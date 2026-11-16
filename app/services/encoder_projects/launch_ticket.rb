# frozen_string_literal: true

require 'uri'

module EncoderProjects
  class LaunchTicket
    PURPOSE = 'vidb-desktop-montage'

    def self.issue(record:, user:, url:)
      raise ArgumentError, 'Qualifie la fiche avant de préparer son montage.' unless supported?(record)

      data = { 'record_id' => record.id, 'user_id' => user.id, 'project_id' => SecureRandom.uuid, 'origin' => url }
      ticket = Rails.application.message_verifier(PURPOSE).generate(data, purpose: PURPOSE)
      "vidb-encoder://prepare?#{URI.encode_www_form(ticket: ticket, origin: url)}"
    end

    def self.read(ticket, user:, url: nil)
      raise ArgumentError, 'Demande de préparation invalide.' unless valid_ticket?(ticket)

      data = Rails.application.message_verifier(PURPOSE).verified(ticket, purpose: PURPOSE)
      raise ArgumentError, 'Demande invalide ou destinée à un autre compte ou serveur vidb.' unless
        valid_context?(data, user, url)

      record = Record.find(data.fetch('record_id'))
      raise ArgumentError, 'La nature ou le placement de la fiche doit être corrigé.' unless supported?(record)

      data.merge('record_title' => record.complete_title_with_parents)
    end

    def self.supported?(record)
      %w[standalone_video episode].include?(record.record_kind) && Matcher.qualified?(record)
    end

    def self.valid_ticket?(ticket)
      ticket.is_a?(String) && ticket.bytesize <= 6000
    end

    def self.valid_context?(data, user, url)
      data.is_a?(Hash) && data['user_id'] == user.id && ProjectRequest::UUID.match?(data['project_id'].to_s) &&
        (url.nil? || data['origin'] == url)
    end
    private_class_method :valid_ticket?, :valid_context?
  end
end
