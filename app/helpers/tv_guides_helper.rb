module TvGuidesHelper
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
