# frozen_string_literal: true

require 'uri'

module EncoderProjects
  class DesktopTicket
    PURPOSE = 'vidb-desktop-action'
    ACTIONS = %w[new_montage open_project encode_dvd show_queue change_version].freeze

    def self.issue(action:, user:, url:)
      raise ArgumentError, 'Commande de montage inconnue' unless ACTIONS.include?(action)

      data = { 'action' => action, 'user_id' => user.id, 'origin' => url }
      ticket = Rails.application.message_verifier(PURPOSE).generate(data, purpose: PURPOSE)
      "vidb-encoder://desktop?#{URI.encode_www_form(ticket: ticket, origin: url)}"
    end

    def self.read(ticket, user:, url:)
      raise ArgumentError, 'Commande de montage invalide' unless ticket.is_a?(String) && ticket.bytesize <= 6000

      data = Rails.application.message_verifier(PURPOSE).verified(ticket, purpose: PURPOSE)
      raise ArgumentError, 'Commande invalide ou destinée à un autre compte ou serveur' unless valid?(data, user, url)

      { 'desktop_action' => data.fetch('action') }
    end

    def self.valid?(data, user, url)
      data.is_a?(Hash) && data['user_id'] == user.id && data['origin'] == url && ACTIONS.include?(data['action'])
    end
    private_class_method :valid?
  end
end
