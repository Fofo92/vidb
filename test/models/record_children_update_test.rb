require "test_helper"

class RecordChildrenUpdateTest < ActiveSupport::TestCase
  setup do
    @vf = LanguageVersion.create!(short_name: "VF", long_name: "Français")
    @vost = LanguageVersion.create!(short_name: "VOST", long_name: "Sous-titré")
    @hd = Medium.create!(short_name: "HD", long_name: "Disque")
    @genre = Gender.create!(name: "Documentaire")
    @country = Country.create!(long_name: "Australie", short_name: "AU")
    @series = Record.create!(french_title: "Série", record_kind: "series", language_version: @vf)
    @season = @series.children.create!(french_title: "Saison 01", record_kind: "season", rank: 1,
                                      language_version: @vf)
    @first = @season.children.create!(french_title: "Premier", record_kind: "episode", rank: 3,
                                     language_version: @vf, year: 2017)
    @second = @season.children.create!(french_title: "Second", record_kind: "undetermined", rank: 4,
                                      language_version: @vf)
  end

  test "changes multiple fields and preserves placement and unselected children" do
    assert operation([@first], fields: %w[year gender_ids country_ids medium_ids language_version_id],
                              year: "2018", year_basis: "production", gender_ids: [@genre.id],
                              country_ids: [@country.id], medium_ids: [@hd.id],
                              language_version_id: @vost.id).call
    @first.reload
    assert_equal 2018, @first.year
    assert_equal "production", @first.year_basis
    assert_equal [@genre.id], @first.gender_ids
    assert_equal [@country.id], @first.country_ids
    assert_equal [@hd.id], @first.medium_ids
    assert_equal @vost.id, @first.language_version_id
    assert_equal 3, @first.rank
    assert_equal @season.id, @first.parent_id
    assert_nil @second.reload.year
  end

  test "row overrides common values including an explicit empty association" do
    @first.genders << @genre
    rows = { @first.id.to_s => { fields: %w[year gender_ids], year: "2020", year_basis: "first_release",
                                gender_ids: [""] } }
    assert operation([@first, @second], { fields: %w[year gender_ids], year: "2019", year_basis: "production",
                                         gender_ids: [@genre.id] }, rows: rows).call
    assert_equal 2020, @first.reload.year
    assert_empty @first.gender_ids
    assert_equal "first_release", @first.year_basis
    assert_equal 2019, @second.reload.year
    assert_equal [@genre.id], @second.gender_ids
  end

  test "leaves unchecked fields and existing year provenance unchanged" do
    @first.update!(year_basis: "first_release", year_evidence: { "source" => "TMDB" })
    assert operation([@first], fields: ["gender_ids"], gender_ids: [@genre.id], year: "2022").call
    assert_equal 2017, @first.reload.year
    assert_equal({ "source" => "TMDB" }, @first.year_evidence)
  end

  test "explicitly confirms unseen state and preserves availability from copies" do
    asset = create_asset(@first)
    assert operation([@first], fields: ["is_seen"], is_seen: "no").call
    assert_equal false, @first.reload.effective_state(:is_seen)
    assert @first.seen_state_confirmed_at
    assert @first.is_available
    assert_equal "present", asset.reload.status
  end

  test "applies states to leaves below selected seasons" do
    assert operation([@season], { fields: %w[is_seen is_checked], is_seen: "yes", is_checked: "yes" },
                     parent: @series).call
    assert @first.reload.is_seen
    assert @second.reload.is_seen
    assert @first.is_checked
    assert_equal 1, @season.reload.rank
  end

  test "changes copies only when explicitly requested and preserves language history" do
    asset = create_asset(@first, language_version: @vf,
                         technical_details: { "streams" => [], "language_qualification" => { "reason" => "VF présumée" } })
    assert operation([@first], fields: ["language_version_id"], language_version_id: @vost.id).call
    assert_equal @vf.id, asset.reload.language_version_id
    assert operation([@first], fields: %w[copy_language_version_id copy_medium_id],
                              copy_language_version_id: @vost.id, copy_medium_id: @hd.id).call
    assert_equal @vost.id, asset.reload.language_version_id
    assert_equal @hd.id, asset.medium_id
    assert_equal "VF présumée", asset.technical_details.dig("language_qualification_history", 0, "qualification", "reason")
    assert_equal "Qualification manuelle", asset.technical_details.dig("language_qualification", "reason")
  end

  test "does not change deleted copies" do
    asset = create_asset(@first, status: "deleted", language_version: @vf)
    assert operation([@first], fields: ["copy_language_version_id"], copy_language_version_id: @vost.id).call
    assert_equal @vf.id, asset.reload.language_version_id
  end

  test "rolls back all edits if one row is invalid" do
    rows = { @second.id.to_s => { fields: ["year"], year: "1800" } }
    update = operation([@first, @second], { fields: ["year"], year: "2019" }, rows: rows)
    assert_not update.call
    assert_equal 2017, @first.reload.year
    assert_nil @second.reload.year
  end

  test "rejects stale data including changes on an unselected descendant" do
    update = operation([@first], fields: ["is_seen"], is_seen: "yes")
    @second.update!(year: 2021)
    assert_not update.call
    assert_match(/changé/, update.errors.full_messages.join)
    assert_not @first.reload.is_seen
  end

  test "rejects children outside the parent and empty selections" do
    assert_not operation([@season], fields: ["is_seen"], is_seen: "yes").call
    assert_not operation([], fields: ["is_seen"], is_seen: "yes").call
  end

  test "rejects unsupported fields invalid references and invalid states" do
    assert_not operation([@first], fields: ["is_available"], is_available: "yes").call
    assert_not operation([@first], fields: ["gender_ids"], gender_ids: ["invalid"]).call
    assert_not operation([@first], fields: ["country_ids"], country_ids: [99999999]).call
    assert_not operation([@first], fields: ["language_version_id"], language_version_id: "").call
    assert_not operation([@first], fields: ["is_seen"], is_seen: "perhaps").call
    assert_not operation([@first], fields: []).call
  end

  test "qualifies nature without changing rank and rejects incompatible nature" do
    assert operation([@second], fields: ["record_kind"], record_kind: "episode").call
    assert_equal "episode", @second.reload.record_kind
    assert_equal 4, @second.rank
    assert_not operation([@second], fields: ["record_kind"], record_kind: "season").call
  end

  test "retains year history and can clear the year" do
    assert operation([@first], fields: ["year"], year: "2019", year_basis: "first_release").call
    assert_equal 2017, @first.reload.year_history.last["year"]
    assert operation([@first], fields: ["year"], year: "", year_basis: "production").call
    assert_nil @first.reload.year
    assert_equal "unknown", @first.year_basis
    assert_empty @first.year_evidence
  end

  test "preserves existing evidence for an unchanged year and basis" do
    @first.update!(year_basis: "first_release", year_evidence: { "source" => "TMDB" })
    history = @first.year_history
    assert operation([@first], fields: ["year"], year: "2017", year_basis: "first_release").call
    assert_equal({ "source" => "TMDB" }, @first.reload.year_evidence)
    assert_equal history, @first.year_history
  end

  test "keeps manual provenance when changing a year with the same basis" do
    assert operation([@first], fields: ["year"], year: "2018", year_basis: "production").call
    assert operation([@first], fields: ["year"], year: "2019", year_basis: "production").call
    assert_equal "production", @first.reload.year_basis
    assert_equal 2019, @first.year_evidence["year"]
  end

  test "unknown viewing clears confirmation and copy updates reach season leaves" do
    asset = create_asset(@first)
    assert operation([@first], fields: ["is_seen"], is_seen: "no").call
    assert operation([@first], fields: ["is_seen"], is_seen: "unknown").call
    assert_nil @first.reload.seen_state_confirmed_at
    assert_nil @first.effective_state(:is_seen)
    assert operation([@season], { fields: ["copy_language_version_id"], copy_language_version_id: @vost.id },
                     parent: @series).call
    assert_equal @vost.id, asset.reload.language_version_id
  end

  test "rejects missing values malformed years and incompatible descendant placement" do
    assert_not operation([@first], fields: ["year"]).call
    assert_not operation([@first], fields: ["year"], year: "20XX").call
    assert_not operation([@first], fields: ["year"], year: "2020", year_basis: "invalid").call
    assert_not operation([@season], { fields: ["record_kind"], record_kind: "episode" }, parent: @series).call
  end

  private

  def operation(children, common = nil, rows: {}, parent: @season, **values)
    RecordChildrenUpdate.new(
      parent: parent, child_ids: children.map(&:id), common: (common || values).deep_stringify_keys,
      rows: rows.deep_stringify_keys,
      snapshots: {
        children: children.to_h { |child| [child.id.to_s, RecordChildQualificationSnapshot.token(child.reload)] },
        parent: RecordChildQualificationSnapshot.token(parent.reload)
      }
    )
  end

  def create_asset(record, **attributes)
    VideoAsset.create!({ record: record, status: "present", last_known_path: "/videos/#{record.id}.mkv" }.merge(attributes))
  end
end
