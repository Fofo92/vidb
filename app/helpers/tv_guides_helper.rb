module TvGuidesHelper
  def tv_programme_title(programme)
    localized_value(programme.titles, "fr") ||
      first_value(programme.titles)
  end

  def tv_programme_original_title(programme)
    entry = programme.titles.find do |title|
      title["language"].present? &&
        title["language"] != "fr"
    end

    entry&.fetch("value", nil)
  end

  def tv_programme_subtitle(programme)
    localized_value(programme.subtitles, "fr") ||
      first_value(programme.subtitles)
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
    entry = programme.episode_numbers.find do |number|
      number["system"] == "xmltv_ns"
    end
    match = entry&.fetch("value", nil)&.match(
      /\A(\d+)\.(\d+)\./
    )
    return unless match

    "Saison #{match[1].to_i + 1}, épisode #{match[2].to_i + 1}"
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
