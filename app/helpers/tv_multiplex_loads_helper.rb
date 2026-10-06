module TvMultiplexLoadsHelper
  def tv_multiplex_label(segment)
    count = segment.multiplexes.size
    return count.to_s if segment.unknown_channels.empty?

    count.zero? ? "?" : "#{count}+?"
  end

  def tv_multiplex_position(minute)
    lower = @timeline_projection.position_for(minute.floor)
    upper = @timeline_projection.position_for(minute.ceil)
    lower + ((upper - lower) * (minute - minute.floor))
  end

  def tv_multiplex_description(segment)
    lines = ["#{tv_multiplex_time(segment.starts_at)} – #{tv_multiplex_time(segment.ends_at)}",
             "#{segment.multiplexes.size} multiplex connu(s) / #{Tv::MultiplexCapacityGuard::TUNERS} tuners"]
    lines << "Multiplex : #{segment.multiplexes.map { |number| "R#{number}" }.join(', ')}"
    lines << "Multiplex inconnu : #{segment.unknown_channels.join(', ')}" if segment.unknown_channels.any?
    lines << "Dépassement des quatre tuners." if segment.multiplexes.size > Tv::MultiplexCapacityGuard::TUNERS
    lines + segment.captures.map { |capture| "#{capture.channel} (R#{capture.multiplex || '?'}) : #{capture.title}" }
  end

  def tv_multiplex_time(time)
    time.in_time_zone("Europe/Paris").strftime("%d/%m %H:%M:%S %Z")
  end
end
