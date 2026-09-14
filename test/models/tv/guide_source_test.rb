require "test_helper"

module Tv
  class GuideSourceTest < ActiveSupport::TestCase
    test "requires an internal name" do
      source = build_source(name: nil)

      assert_not source.valid?
      assert source.errors[:name].any?
    end

    test "requires a display name" do
      source = build_source(display_name: nil)

      assert_not source.valid?
      assert source.errors[:display_name].any?
    end

    test "defaults to enabled and Europe Paris time" do
      source = build_source

      assert source.enabled?
      assert_equal "Europe/Paris", source.time_zone
    end

    test "requires a unique internal name" do
      build_source.save!
      duplicate = build_source(display_name: "Autre libellé")

      assert_not duplicate.valid?
      assert duplicate.errors[:name].any?
    end

    private

    def build_source(attributes = {})
      GuideSource.new(
        {
          name: "xml_tv_fr",
          display_name: "XML TV Fr"
        }.merge(attributes)
      )
    end
  end
end
