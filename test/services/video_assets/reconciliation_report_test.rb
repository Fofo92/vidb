# frozen_string_literal: true

require 'test_helper'

module VideoAssets
  class ReconciliationReportTest < ActiveSupport::TestCase
    setup do
      @language_version = LanguageVersion.create!(
        short_name: 'VF',
        long_name: 'Version française'
      )
      @record = create_record('Tu ne tueras point', 'Hacksaw Ridge')
    end

    test 'matches an exact french title' do
      observation = report_for('Tu ne tueras point.mkv')

      assert_equal 'exact', observation.fetch(:status)
      assert_equal [@record.id], candidate_ids(observation)
    end

    test 'matches an exact original title' do
      observation = report_for('Hacksaw Ridge.m4v')

      assert_equal 'exact', observation.fetch(:status)
      assert_equal [@record.id], candidate_ids(observation)
    end

    test 'matches after removing documented language suffixes' do
      observation = report_for('Tu ne tueras point (VF)_vf.m4v')

      assert_equal 'convention', observation.fetch(:status)
      assert_equal [@record.id], candidate_ids(observation)
    end

    test 'reports ambiguous exact matches' do
      duplicate = create_record('Tu ne tueras point', nil)
      observation = report_for('Tu ne tueras point.mkv')

      assert_equal 'ambiguous_exact', observation.fetch(:status)
      assert_equal [@record.id, duplicate.id].sort, candidate_ids(observation).sort
    end

    test 'defers episode matching' do
      observation = report_for('S01 E01 - Pilote.mkv', episode: { season: 1, episode: 1 })

      assert_equal 'deferred_episode', observation.fetch(:status)
      assert_empty observation.fetch(:candidates)
    end

    test 'excludes formats outside the initial scope' do
      report = build_report(entries: [entry_for('Vidéo personnelle.mp4')])

      assert_empty report.fetch(:observations)
    end

    test 'preserves the source inventory timestamp' do
      report = build_report(entries: [entry_for('Tu ne tueras point.mkv')])

      assert_equal(
        '2026-10-05T00:05:30+02:00',
        report.dig(:source_inventory, :generated_at)
      )
    end

    test 'defers legacy episode prefixes without inventory metadata' do
      ['E01 - Pilote.mkv', 'Épisode 1.m4v', 'S01 E01 - Pilote.mkv'].each do |filename|
        observation = report_for(filename)

        assert_equal 'deferred_episode', observation.fetch(:status)
        assert_empty observation.fetch(:candidates)
      end
    end

    test 'does not mistake titles beginning with episode letters for episodes' do
      record = create_record('E.T.', nil)
      observation = report_for('E.T..mkv')

      assert_equal 'exact', observation.fetch(:status)
      assert_equal [record.id], candidate_ids(observation)
    end

    test 'reports distinct files targeting the same record' do
      report = build_report(entries: [
        entry_for('Tu ne tueras point.mkv'),
        entry_for('Tu ne tueras point_vf.m4v')
      ])
      group = report.fetch(:multiple_file_candidates).sole

      assert_equal @record.id, group.fetch(:record_id)
      assert_equal 2, group.fetch(:paths).size
    end

    test 'does not count repeated observations of one path as multiple files' do
      entry = entry_for('Tu ne tueras point.mkv')
      report = build_report(entries: [entry, entry])

      assert_empty report.fetch(:multiple_file_candidates)
    end

    test 'includes hierarchy information in candidates' do
      candidate = report_for('Tu ne tueras point.mkv').fetch(:candidates).sole

      assert_nil candidate.fetch(:ancestry)
      assert_nil candidate.fetch(:rank)
    end

    private

    def create_record(french_title, original_title)
      Record.create!(
        french_title: french_title,
        original_title: original_title,
        language_version: @language_version
      )
    end

    def report_for(filename, episode: nil)
      build_report(entries: [entry_for(filename, episode: episode)])
        .fetch(:observations)
        .sole
    end

    def build_report(entries:)
      ReconciliationReport.new(
        inventory: inventory(entries),
        records: Record.all
      ).call
    end

    def inventory(entries)
      {
        format: ReconciliationReport::SOURCE_FORMAT,
        version: ReconciliationReport::SOURCE_VERSION,
        generated_at: '2026-10-05T00:05:30+02:00',
        roots: ['/videos'],
        entries: entries
      }
    end

    def entry_for(filename, episode: nil)
      extension = File.extname(filename)
      {
        type: 'file',
        path: "/videos/#{filename}",
        relative_path: filename,
        extension: extension,
        stem: File.basename(filename, extension),
        size: 1_024,
        modified_at: '2026-10-04T12:00:00+02:00',
        episode: episode
      }
    end

    def candidate_ids(observation)
      observation.fetch(:candidates).pluck(:record_id)
    end
  end
end
