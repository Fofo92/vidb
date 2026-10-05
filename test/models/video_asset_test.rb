require "test_helper"

class VideoAssetTest < ActiveSupport::TestCase
  setup do
    language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )
    @record = Record.create!(
      french_title: "Film de test",
      language_version: language_version
    )
  end

  test "accepts a present asset with an observed path" do
    asset = build_asset

    assert asset.valid?
    assert asset.status_present?
  end

  test "requires a path for a present asset" do
    asset = build_asset(last_known_path: nil)

    assert_not asset.valid?
    assert asset.errors[:last_known_path].any?
  end

  test "allows a deleted asset without a known path" do
    asset = build_asset(status: "deleted", last_known_path: nil)

    assert asset.valid?
    assert asset.status_deleted?
  end

  test "rejects unsupported statuses" do
    asset = build_asset(status: "candidate")

    assert_not asset.valid?
    assert asset.errors[:status].any?
  end

  test "validates measured values" do
    assert build_asset(duration_minutes: 1, byte_size: 0).valid?
    assert_not build_asset(duration_minutes: 0).valid?
    assert_not build_asset(byte_size: -1).valid?
  end

  test "database rejects a duplicate present path" do
    build_asset.save!
    duplicate = build_asset

    assert_raises(ActiveRecord::RecordNotUnique) { duplicate.save!(validate: false) }
  end

  test "allows a deleted path to be reused by a present asset" do
    build_asset(status: "deleted").save!

    assert build_asset.save!
  end

  private

  def build_asset(attributes = {})
    VideoAsset.new(
      {
        record: @record,
        last_known_path: "/videos/Films/Film de test.mkv",
        duration_minutes: 90,
        byte_size: 1_024,
        container: "matroska"
      }.merge(attributes)
    )
  end
end
