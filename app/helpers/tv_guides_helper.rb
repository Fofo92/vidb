module TvGuidesHelper
  FRENCH_DAYS = %w[dimanche lundi mardi mercredi jeudi vendredi samedi].freeze
  FRENCH_MONTHS = %w[
    janvier février mars avril mai juin juillet août septembre octobre novembre décembre
  ].freeze

  def tv_guide_long_date(date)
    day = date.day == 1 ? "1er" : date.day.to_s
    "#{FRENCH_DAYS[date.wday]} #{day} #{FRENCH_MONTHS[date.month - 1]} #{date.year}".capitalize
  end

  def tv_guide_day_path(date)
    tv_guide_path(
      date: date.iso8601, guide_source_id: @guide_source.id,
      zoom: @minute_height, all_channels: (@show_all_channels ? "1" : nil)
    )
  end

  CHANNEL_LOGOS = {
    "tf1" => "Logo_TF1_2013.svg",
    "france info" => "Franceinfo.svg",
    "franceinfo" => "Franceinfo.svg",
    "arte" => "Arte_Logo_2026.svg",
    "w9" => "W9_2018.svg",
    "6ter" => "Logo_6ter_2016.svg",
    "rmc story" => "RMC_Story_2025.svg",
    "rmc découverte" => "RMC_Découverte_logo_2025.svg",
    "rmc decouverte" => "RMC_Découverte_logo_2025.svg",
    "t18" => "Logo_de_la_chaîne_T18.svg",
    "novo19" => "Logo_NOVO19_-_2025.svg"
  }.freeze

  def tv_channel_logo_url(channel)
    filename = CHANNEL_LOGOS[channel.display_name.strip.downcase]
    return unless filename

    "https://commons.wikimedia.org/wiki/Special:Redirect/file/#{ERB::Util.url_encode(filename)}"
  end

  def tv_channel_logo_class(channel)
    name = channel.display_name.strip.downcase
    return "tv-guide-channel-logo--arte" if name == "arte"
    return "tv-guide-channel-logo--w9" if name == "w9"
    return "tv-guide-channel-logo--novo19" if name == "novo19"
    return "tv-guide-channel-logo--t18" if name == "t18"
  end

  def tv_france_channel_number(channel)
    match = channel.display_name.strip.match(/\AFrance ([2-5])\z/i)
    match[1].to_i if match
  end

  def tv_programme_title(programme)
    Tv::ProgrammeDisplayName.title(programme)
  end

  def tv_programme_label(programme)
    Tv::ProgrammeDisplayName.call(programme)
  end

  def tv_programme_original_title(programme)
    entry = programme.titles.find do |title|
      title["language"].present? &&
        title["language"] != "fr"
    end

    entry&.fetch("value", nil)
  end

  def tv_programme_subtitle(programme)
    Tv::ProgrammeDisplayName.subtitle(programme)
  end

  def tv_programme_category(programme)
    programme.categories
             .map { |category| category["value"] }
             .compact
             .join(", ")
             .presence
  end

  def tv_programme_description(programme)
    localized_value(programme.descriptions, "fr") ||
      first_value(programme.descriptions)
  end

  def tv_programme_episode(programme)
    Tv::ProgrammeEpisodeLabel.call(programme)
  end

  private

  def localized_value(entries, language)
    entry = entries.find { |item| item["language"] == language }

    entry&.fetch("value", nil)
  end

  def first_value(entries)
    entries.first&.fetch("value", nil)
  end
end
