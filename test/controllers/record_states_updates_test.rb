# frozen_string_literal: true

require "test_helper"

class RecordStatesUpdatesTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: "state-updates@example.com", password: "password")
    language = LanguageVersion.create!(short_name: "VF", long_name: "Version française")
    @series = Record.create!(french_title: "Série", language_version: language, record_kind: "series")
    @season = @series.children.create!(french_title: "Saison 01", language_version: language, record_kind: "season")
    @episode = episode("Premier", language)
    @other_episode = episode("Deuxième", language)
    @outside = Record.create!(
      french_title: "Autre", language_version: language, record_kind: "standalone_video", is_seen: nil
    )
  end

  test "an explicit unseen choice stays known on an unchecked episode" do
    update_state(@season, field: "is_seen", value: "no", child_id: @episode.id)
    assert_response :success
    assert_equal false, @episode.reload.effective_state(:is_seen)
    assert_not_nil @episode.seen_state_confirmed_at
    assert_equal false, @episode.is_checked
    assert_nil @other_episode.reload.is_seen
    assert_includes response.parsed_body.fetch("rows"), "✗"
  end

  test "changing editorial verification preserves an explicit unseen choice" do
    update_state(@season, field: "is_seen", value: "no", child_id: @episode.id)
    update_state(@season, field: "is_checked", value: "yes", child_id: @episode.id)
    update_state(@season, field: "is_checked", value: "no", child_id: @episode.id)
    assert_response :success
    assert_equal false, @episode.reload.effective_state(:is_seen)
  end

  test "a column update changes video leaves but not season or series flags" do
    update_state(@series, field: "is_seen", value: "yes")
    assert_response :success
    assert_equal 2, response.parsed_body.fetch("count")
    assert @episode.reload.is_seen
    assert @other_episode.reload.is_seen
    assert_not @season.reload.is_seen
    assert_not @series.reload.is_seen
    assert_includes response.parsed_body.fetch("summary"), "2/2"
  end

  test "unknown clears a previously confirmed seen choice" do
    update_state(@season, field: "is_seen", value: "yes", child_id: @episode.id)
    update_state(@season, field: "is_seen", value: "unknown", child_id: @episode.id)
    assert_response :success
    assert_nil @episode.reload.effective_state(:is_seen)
    assert_nil @episode.seen_state_confirmed_at
  end

  test "an unseen column choice confirms each episode independently of checking" do
    update_state(@season, field: "is_seen", value: "no")
    assert_response :success
    [@episode, @other_episode].each do |record|
      assert_equal false, record.reload.effective_state(:is_seen)
      assert_not_nil record.seen_state_confirmed_at
      assert_not record.is_checked
    end
  end

  test "legacy unchecked false remains unknown" do
    @episode.update!(is_seen: false)
    assert_nil @episode.reload.effective_state(:is_seen)
  end

  test "recorded and available cannot be changed by this endpoint" do
    %w[is_recorded is_available].each do |field|
      update_state(@season, field: field, value: "yes", child_id: @episode.id)
      assert_response :unprocessable_content
      assert_not @episode.reload.public_send(field)
    end
  end

  test "an unrelated record or container row cannot be changed" do
    update_state(@season, field: "is_seen", value: "yes", child_id: @outside.id)
    assert_response :unprocessable_content
    assert_nil @outside.reload.is_seen
    update_state(@series, field: "is_seen", value: "yes", child_id: @season.id)
    assert_response :unprocessable_content
  end

  test "invalid values are rejected without changing records" do
    update_state(@season, field: "is_seen", value: "perhaps")
    assert_response :unprocessable_content
    assert_nil @episode.reload.is_seen
    assert_nil @other_episode.reload.is_seen
  end

  test "a failed bulk update rolls back all changes" do
    @other_episode.update_column(:year, 1890)
    update_state(@season, field: "is_seen", value: "yes")
    assert_response :unprocessable_content
    assert_nil @episode.reload.is_seen
    assert_nil @episode.seen_state_confirmed_at
  end

  test "state controls are present only for editable episode fields" do
    get record_url(@season)
    assert_response :success
    assert_select "th[data-state-column='is_seen'] [data-value='yes']", count: 1
    assert_select "td[data-state-column='is_seen'] button[data-child-id='#{@episode.id}']", count: 3
    assert_select "[data-state-column='is_checked']", count: 0
    assert_select "[data-state-column='is_available'] button", count: 0
  end

  private

  def episode(title, language)
    @season.children.create!(
      french_title: title, language_version: language, record_kind: "episode",
      is_seen: nil, is_checked: false
    )
  end

  def update_state(parent, **attributes)
    patch record_states_url(parent), params: { state: attributes }, as: :json
  end
end
