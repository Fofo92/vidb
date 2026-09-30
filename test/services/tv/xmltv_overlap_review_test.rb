require "test_helper"

module Tv
  class XmltvOverlapReviewTest < ActiveSupport::TestCase
    setup do
      @source = GuideSource.create!(name: "xml_tv_fr", display_name: "XML TV Fr")
      @channel = @source.guide_channels.create!(external_id: "TF1.fr")
      @import = @source.guide_imports.create!(
        document_sha256: "a" * 64, document_byte_size: 100,
        status: "succeeded", started_at: Time.utc(2030, 1, 1),
        finished_at: Time.utc(2030, 1, 1, 0, 1)
      )
    end

    test "compares the common period and reports a selected changed programme" do
      old = programme(0, "Premier")
      changed = programme(1, "Deuxième")
      add_current(old, 1)
      observation = add_current(changed, 2)
      intent = RecordingIntent.create!(broadcast_observation: observation)
      incoming = [old, programme(1, "Deuxième corrigé"), programme(2, "Troisième")]

      report = review(incoming)

      assert_equal [1, 1, 1], [report.unchanged, report.removed, report.added]
      assert_equal [intent.id], report.missing_intent_ids
      assert_equal old.starts_at, report.starts_at
      assert_equal changed.ends_at, report.ends_at
    end

    test "keeps the current guide when a channel loses most programmes" do
      4.times { |index| add_current(programme(index, "Émission #{index}"), index + 1) }

      error = assert_raises(XmltvOverlapReview::InsufficientCoverage) do
        review([programme(0, "Émission 0"), programme(3, "Émission 3")])
      end

      assert_match(/TF1.fr/, error.message)
      assert_equal @import, @source.latest_successful_import
    end

    test "treats an added Saison label as a naming variation" do
      old = programme(0, "MacGyver - Saison 1", episode_number: "0.6.", subtitle: "Evasion")
      observation = add_current(old, 1)
      intent = RecordingIntent.create!(broadcast_observation: observation)
      incoming = programme(0, "MacGyver", episode_number: "0.6.", subtitle: "Evasion")

      result = review([incoming])

      assert_equal [intent.id], result.renamed_intent_ids
      assert_empty result.numbering_intent_ids
      assert_empty result.missing_intent_ids
    end

    test "reports changing episode numbers for the same named story" do
      old = programme(0, "Meurtres à... - Saison 9", episode_number: "8.0.", subtitle: "Meurtres à Amiens")
      observation = add_current(old, 1)
      intent = RecordingIntent.create!(broadcast_observation: observation)
      incoming = programme(0, "Meurtres à...", episode_number: "8.10.", subtitle: "Meurtres à Amiens")

      result = review([incoming])

      assert_equal [intent.id], result.numbering_intent_ids
      assert_empty result.missing_intent_ids
    end

    test "refuses a new guide without any shared period" do
      add_current(programme(0, "Premier"), 1)

      assert_raises(XmltvOverlapReview::InsufficientCoverage) do
        review([programme(48, "Deux jours après")])
      end
    end

    private

    def review(programmes)
      document = XmltvDocument.new(
        source_info_name: nil, source_info_url: nil,
        generator_info_name: nil, generator_info_url: nil,
        channels: {}, programmes:, duplicate_programme_count: 0
      )
      XmltvOverlapReview.new(guide_source: @source, document:).call
    end

    def add_current(programme, number)
      observation = @channel.broadcast_observations.create!(
        fingerprint: XmltvObservationFingerprint.new(guide_source: @source, programme:).call,
        starts_at: programme.starts_at, ends_at: programme.ends_at,
        titles: programme.titles.map(&:stringify_keys),
        subtitles: programme.subtitles.map(&:stringify_keys),
        episode_numbers: programme.episode_numbers.map(&:stringify_keys)
      )
      @import.guide_import_observations.create!(broadcast_observation: observation)
      observation
    end

    def programme(hour, title, episode_number: nil, subtitle: nil)
      starts_at = Time.utc(2030, 1, 2) + hour.hours
      XmltvProgramme.new(
        channel_id: "TF1.fr", starts_at:, ends_at: starts_at + 1.hour,
        source_start: nil, source_stop: nil,
        titles: [{ value: title, language: "fr" }],
        subtitles: subtitle ? [{ value: subtitle, language: "fr" }] : [],
        descriptions: [], categories: [],
        episode_numbers: episode_number ? [{ value: episode_number, system: "xmltv_ns" }] : []
      )
    end
  end
end
