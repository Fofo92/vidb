require "test_helper"

module Tv
  class GuideImportObservationTest < ActiveSupport::TestCase
    setup do
      source = GuideSource.create!(
        name: "xml_tv_fr",
        display_name: "XML TV Fr"
      )
      guide_channel = source.guide_channels.create!(
        external_id: "C192.api.telerama.fr"
      )
      @guide_import = source.guide_imports.create!(
        document_sha256: "a" * 64,
        document_byte_size: 1_024
      )
      @observation = guide_channel.broadcast_observations.create!(
        fingerprint: "b" * 64,
        starts_at: Time.utc(2026, 9, 15, 20),
        ends_at: Time.utc(2026, 9, 15, 21)
      )
    end

    test "requires an import and an observation" do
      {
        guide_import: nil,
        broadcast_observation: nil
      }.each do |association, value|
        link = build_link(association => value)

        assert_not link.valid?
        assert link.errors[association].any?
      end
    end

    test "links an observation only once within an import" do
      build_link.save!
      duplicate = build_link

      assert_not duplicate.valid?
      assert duplicate.errors[:broadcast_observation].any?
    end

    test "allows an observation to appear in several imports" do
      build_link.save!
      other_import = @guide_import.guide_source.guide_imports.create!(
        document_sha256: "c" * 64,
        document_byte_size: 2_048
      )

      assert build_link(guide_import: other_import).valid?
    end

    test "exposes the relation from both sides" do
      build_link.save!

      assert_equal(
        [@observation],
        @guide_import.broadcast_observations.to_a
      )
      assert_equal(
        [@guide_import],
        @observation.guide_imports.to_a
      )
    end

    test "prevents destroying a linked import" do
      build_link.save!

      assert_not @guide_import.destroy
      assert @guide_import.errors[:base].any?
      assert GuideImport.exists?(@guide_import.id)
    end

    test "prevents destroying a linked observation" do
      build_link.save!

      assert_not @observation.destroy
      assert @observation.errors[:base].any?
      assert BroadcastObservation.exists?(@observation.id)
    end

    private

    def build_link(attributes = {})
      GuideImportObservation.new(
        {
          guide_import: @guide_import,
          broadcast_observation: @observation
        }.merge(attributes)
      )
    end
  end
end
