require "test_helper"

class RecordContainerMetadataTest < ActiveSupport::TestCase
  setup do
    @vf = LanguageVersion.create!(short_name: "VF", long_name: "Français conteneurs")
    @unknown = LanguageVersion.create!(short_name: "?", long_name: "Inconnue conteneurs")
    @hd = Medium.create!(short_name: "HD", long_name: "HD conteneurs")
    @country = Country.create!(short_name: "AU", long_name: "Australie conteneurs")
    @genre = Gender.create!(name: "Documentaire conteneurs")
    @series = create_record("Série", "series", countries: [@country], genders: [@genre], abstract: "Résumé général")
    @season = create_record("Saison 01", "season", parent: @series)
    @episode = create_record("Épisode", "episode", parent: @season, year: 2020,
                             year_basis: "first_release", abstract: "Résumé", length_in_mn: 45, media: [@hd])
  end

  test "references inherit without modifying stored associations and explicit exceptions win" do
    assert_equal [@country], @episode.effective_countries
    assert_equal [@genre], @season.effective_genders
    assert_empty @episode.reload.countries
    exception = Country.create!(short_name: "FR", long_name: "France conteneurs")
    @episode.countries << exception
    assert_equal [exception], @episode.effective_countries
    assert_equal [@country], @series.reload.countries
    assert_includes RecordIndexFilter.new({ country_id: exception.id }).call.pluck(:id), @episode.id
    assert_not_includes RecordIndexFilter.new({ country_id: @country.id }).call.pluck(:id), @episode.id
  end

  test "audit assigns common reference gaps to the series and video gaps to the episode" do
    @series.countries.clear
    @series.genders.clear
    @episode.update!(year: nil, abstract: nil, language_version: @unknown)
    result = RecordMetadataAudit.new.call
    rows = result[:records].index_by { |row| row[:id] }
    assert_equal %i[country genres], rows.fetch(@series.id)[:missing]
    assert_not rows.key?(@season.id)
    assert_equal %i[year abstract language], rows.fetch(@episode.id)[:missing]
    assert_equal result[:total], result[:groups].values.sum { |group| group[:total] }
    assert_equal result[:to_work], result[:groups].values.sum { |group| group[:to_work] }
  end

  test "empty containers ignore their own legacy video values" do
    @episode.destroy!
    @season.update!(length_in_mn: 120, year: 1999, language_version: @vf, media: [@hd])
    summary = summary_for(@season)
    assert_equal "—", summary.summary_duration
    assert_equal "—", summary.summary_languages
    assert_equal "—", summary.summary_supports
    assert_nil @season.display_range_of_years
    row = RecordMetadataAudit.new.call[:records].find { |item| item[:id] == @season.id }
    assert_empty row[:missing]
    assert_includes row[:review], "Ensemble sans enfant"
  end

  test "duration sums episodes while alternative copies form a range" do
    copy(@episode, "first", duration_minutes: 40)
    copy(@episode, "second", duration_minutes: 50)
    create_record("Autre épisode", "episode", parent: @season, length_in_mn: 30, media: [@hd])
    summary = summary_for(@series)
    assert_equal "01:10–01:20", summary.summary_duration
    assert_includes summary.duration, "durées de fiches incluses"
    assert_equal "VF", summary.summary_languages
    assert_equal "HD", summary.summary_supports
  end

  test "duration does not wrap after twenty four hours" do
    @episode.update!(length_in_mn: 240)
    6.times { |index| create_record("Long #{index}", "episode", parent: @season, length_in_mn: 240) }
    assert_equal "28h00", @series.formatted_total_length
    assert_equal "28h00", summary_for(@series).summary_duration
    assert_equal 1680, @series.child_length_in_mn
  end

  test "unknown languages do not become question marks in compact summaries" do
    @episode.update!(language_version: @unknown)
    assert_equal "—", summary_for(@series).summary_languages
    assert_equal false, @episode.reload.is_seen
  end

  test "mixed coverage uses fallback per video and never inherits an unqualified copy" do
    copy(@episode, "unqualified", language_version: nil, medium: nil)
    vost = LanguageVersion.create!(short_name: "VOST", long_name: "Sous-titré conteneurs")
    create_record("Sans copie", "episode", parent: @season, language_version: vost, media: [@hd])
    assert_equal "VOST", summary_for(@series).summary_languages
    assert_equal "HD", summary_for(@series).summary_supports
    assert_equal "—", summary_for(@episode).summary_languages
  end

  test "complete broadcast parts sum while incomplete measurements use a lower bound" do
    @episode.update!(broadcast_part_count: 2, length_in_mn: nil)
    copy(@episode, "part1", broadcast_part_number: 1, duration_minutes: 30)
    assert_equal "—", summary_for(@series).summary_duration
    copy(@episode, "part2", broadcast_part_number: 2, duration_minutes: 30)
    assert_equal "01:00", summary_for(@series).summary_duration
    create_record("Sans durée", "episode", parent: @season)
    assert_equal "≥ 01:00", summary_for(@series).summary_duration
  end

  private

  def create_record(title, kind, **attributes)
    Record.create!({ french_title: title, record_kind: kind, language_version: @vf }.merge(attributes))
  end

  def copy(record, name, **attributes)
    VideoAsset.create!({ record: record, status: "present", last_known_path: "/videos/container-#{name}.mkv",
                         language_version: @vf, medium: @hd }.merge(attributes))
  end

  def summary_for(record)
    records = record.subtree.includes(:media, :language_version).to_a
    VideoAssets::DisplaySummary.new(record: record, records: records,
                                   assets: VideoAsset.where(record_id: records.map(&:id), status: "present").to_a)
  end
end
