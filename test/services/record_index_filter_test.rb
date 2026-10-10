require "test_helper"

class RecordIndexFilterTest < ActiveSupport::TestCase
  setup do
    @vf = LanguageVersion.create!(short_name: "VF", long_name: "Français filtre")
    @vost = LanguageVersion.create!(short_name: "VOST", long_name: "Sous-titré filtre")
    @country = Country.create!(short_name: "AU", long_name: "Australie filtre")
    @genre = Gender.create!(name: "Documentaire filtre")
    @series = create_record("Série filtre", "series")
    @season = create_record("Saison filtre", "season", parent: @series)
    @episode = create_record("Épisode filtre", "episode", parent: @season,
                             countries: [@country], genders: [@genre], year: 2020)
    @other = create_record("Autre filtre", "standalone_video", countries: [@country])
  end

  test "combines criteria on the same record" do
    results = filter(country_id: @country.id, gender_id: @genre.id, year: 2020).call
    assert_equal [@episode.id], results.pluck(:id)
  end

  test "includes the anchor and descendants but excludes other trees" do
    results = filter(tree_id: @season.id).call
    assert_equal [@season.id, @episode.id].sort, results.pluck(:id).sort
  end

  test "tree display keeps parents and siblings as context despite the title search" do
    sibling = create_record("Autre épisode filtre", "episode", parent: @season)
    search = Record.where(id: @episode.id)
    operation = RecordIndexFilter.new({ country_id: @country.id, display: "trees" }, scope: search)
    assert_equal [@series.id, @season.id, @episode.id, sibling.id].sort, operation.call.pluck(:id).sort
    assert_equal [@episode.id], operation.matched_ids
  end

  test "tree context remains limited to the selected branch" do
    results = filter(tree_id: @season.id, gender_id: @genre.id, display: "trees").call
    assert_equal [@season.id, @episode.id].sort, results.pluck(:id).sort
  end

  test "present copy language takes precedence over the record" do
    VideoAsset.create!(record: @episode, status: "present", last_known_path: "/videos/filtre.mkv",
                       language_version: @vost)
    assert_includes filter(language_version_id: @vost.id).call.pluck(:id), @episode.id
    assert_not_includes filter(language_version_id: @vf.id).call.pluck(:id), @episode.id
  end

  test "filters missing information and rejects an invalid tree" do
    Rails.cache.delete("record-metadata-filter-v1")
    assert_includes filter(missing: "country", tree_id: @series.id).call.pluck(:id), @series.id
    assert_not_includes filter(missing: "country", tree_id: @series.id).call.pluck(:id), @episode.id
    assert_raises(ActiveRecord::RecordNotFound) { filter(tree_id: "not-an-id").call }
  end

  test "roots display returns matching roots only" do
    operation = filter(country_id: @country.id, display: "roots")
    assert_equal [@other.id], operation.call.pluck(:id)
    assert_equal [@other.id], operation.matched_ids
  end

  test "tree display preserves local ranks rather than sorting children by title" do
    @episode.update!(rank: 2)
    first = create_record("Zulu filtre", "episode", parent: @season, rank: 1)
    assert_equal [@series.id, @season.id, first.id, @episode.id],
                 filter(gender_id: @genre.id, display: "trees").call.pluck(:id)
  end

  test "tree options distinguish identically named seasons by their parents" do
    options = RecordTreeOptions.new.call
    assert_includes options, ["Série filtre / Saison filtre — ##{@season.id}", @season.id]
    assert_not options.any? { |_title, id| id == @other.id }
  end

  test "support filters use copies and fall back only for records without present copies" do
    hd = Medium.create!(short_name: "HD", long_name: "HD filtre")
    dvd = Medium.create!(short_name: "DVD", long_name: "DVD filtre")
    @episode.media << dvd
    @other.media << dvd
    VideoAsset.create!(record: @episode, status: "present", last_known_path: "/videos/support-filtre.mkv", medium: hd)
    assert_includes filter(medium_id: hd.id).call.pluck(:id), @episode.id
    assert_equal [@other.id], filter(medium_id: dvd.id).call.pluck(:id)
  end

  test "consolidation filters use the same reasons as the metadata audit" do
    Rails.cache.delete("record-metadata-filter-v1")
    assert_includes filter(review: "1", tree_id: @series.id).call.pluck(:id), @episode.id
  end

  private

  def filter(**values)
    RecordIndexFilter.new(values)
  end

  def create_record(title, kind, **attributes)
    Record.create!({ french_title: title, record_kind: kind, language_version: @vf }.merge(attributes))
  end
end
