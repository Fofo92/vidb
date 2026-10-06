module Tv
  # Checks the tuner demand of a proposed capture against Kaffeine's live schedule.
  # Mapping: tv-capture-prototype/data/kaffeine_channels_source.csv (Zeus, September 2026).
  class MultiplexCapacityGuard
    TUNERS = 4
    MULTIPLEXES = {
      1 => ["France 2", "F3 Paris Ile-de-France", "France 4"],
      2 => ["CNEWS", "Gulli", "T18", "CSTAR", "NOVO19"],
      4 => ["France 5", "M6", "Arte", "W9", "6Ter", "PARIS PREMIERE"],
      6 => ["TF1", "TMC", "TFX", "LCP"],
      10 => [
        "TF1 Séries Films", "RMC STORY", "RMC Découverte", "RMC Life",
        "L'Equipe", "L’Équipe", "L'Équipe"
      ]
    }.freeze

    class Warning < StandardError; end

    def initialize(schedules:, attributes:)
      @schedules = schedules
      @attributes = attributes
    end

    def check!
      candidate = interval(@attributes)
      overlapping = @schedules.select { |entry| overlaps?(interval(entry), candidate) }
      boundaries = ([candidate.first, candidate.last] + overlapping.flat_map { |entry| interval(entry) })
                   .grep(candidate.first..candidate.last).uniq.sort

      boundaries.each_cons(2) do |starts_at, ends_at|
        active = overlapping.select { |entry| covers?(interval(entry), starts_at) }
        inspect_segment(active, starts_at, ends_at)
      end
    end

    private

    def inspect_segment(active, starts_at, ends_at)
      channels = active.map(&:channel) + [@attributes.fetch(:channel)]
      unknown = channels.reject { |name| multiplex(name) }
      verify_known_channels!(active, unknown)

      count = channels.map { |name| multiplex(name) }.uniq.size
      return if count <= TUNERS

      zone = Time.find_zone!("Europe/Paris")
      window = "#{starts_at.in_time_zone(zone).strftime('%d/%m %H:%M')}–" \
               "#{ends_at.in_time_zone(zone).strftime('%H:%M')}"
      raise Warning, "conflit de multiplex #{window} : #{count} multiplex pour #{TUNERS} tuners."
    end

    def verify_known_channels!(active, unknown)
      return if unknown.empty? && active.none? { |entry| entry.repeat != 0 }

      raise Warning, "multiplex ou répétition non vérifiable (#{unknown.uniq.join(', ')}) ; programmation suspendue."
    end

    def interval(value)
      starts_at = value.respond_to?(:starts_at) ? value.starts_at : value.fetch(:starts_at)
      duration = value.respond_to?(:duration_seconds) ? value.duration_seconds : value.fetch(:duration_seconds)
      [starts_at, starts_at + duration.seconds]
    end

    def overlaps?(first, second)
      first.first < second.last && second.first < first.last
    end

    def covers?(window, time)
      window.first <= time && time < window.last
    end

    def multiplex(name)
      MULTIPLEXES.find { |_number, names| names.include?(name) }&.first
    end
  end
end
