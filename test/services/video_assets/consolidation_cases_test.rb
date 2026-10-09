require "test_helper"

class ConsolidationCasesTest < ActiveSupport::TestCase
  test "groups different obstacles and seasons into a single series case" do
    entries = [entry("/videos/Série/Saison 01/a.mkv", reason: "container_unmatched"),
               entry("/videos/Série/Saison 02/b.mkv", reason: "season_unmatched")]
    result = consolidate(entries)
    assert_equal 1, result[:case_count]
    item = result[:cases].first
    assert_equal "/videos/Série", item[:directory]
    assert_equal 2, item[:file_count]
    assert_equal({ "series_identification" => 1, "missing_season" => 1 }, item[:categories])
    assert_equal [12], item[:record_ids]
    assert_equal 2, item[:actions].length
  end

  test "puts actual identity conflicts before large unidentified series" do
    entries = [entry("/videos/Grande série/a.mkv", reason: "container_unmatched"),
               entry("/videos/Grande série/b.mkv", reason: "container_unmatched"),
               entry("/videos/Petit conflit/a.mkv", status: "episode_title_conflict")]
    result = consolidate(entries)
    assert_equal "/videos/Petit conflit", result[:cases].first[:directory]
    assert_equal [1, 2], result[:cases].map { |item| item[:case_number] }
  end

  test "confirmed and recent copies do not become reconciliation cases" do
    entries = [entry("/videos/a.mkv", followup_status: "confirmed"),
               entry("/videos/b.mkv", followup_status: "awaiting_stability")]
    result = consolidate(entries)
    assert_equal 0, result[:case_count]
    assert_equal 1, result[:file_counts]["confirmed"]
    assert_equal 1, result[:file_counts]["awaiting_stability"]
  end

  test "includes linguistic exceptions separately from matching and deduplicates paths" do
    path = "/videos/Films/Drame/a.mkv"
    entries = [entry(path, followup_status: "candidate")]
    result = consolidate(entries, [{ path: path, reason: "Marque VF et pistes contradictoires" }])
    assert_equal 1, result[:case_count]
    assert_equal 1, result[:cases].first[:file_count]
    assert_equal({ "candidate" => 1, "language_review" => 1 }, result[:cases].first[:categories])
    assert_equal 2, result[:cases].first[:actions].length
  end

  test "rejects an unsupported followup without writing records" do
    assert_no_difference "Record.count" do
      assert_raises(ArgumentError) { VideoAssets::ConsolidationCases.new(followup: {}).call }
    end
  end

  private

  def entry(path, **attributes)
    { path: path, followup_status: "needs_review", status: "deferred_episode",
      candidates: [{ record_id: 12 }] }.merge(attributes)
  end

  def consolidate(entries, language_exceptions = [])
    VideoAssets::ConsolidationCases.new(
      followup: { format: VideoAssets::ReconciliationFollowup::FORMAT, version: 1,
                  inventory_at: "2026-10-10T01:20:00+02:00", entries: entries },
      language_exceptions: language_exceptions
    ).call
  end
end
