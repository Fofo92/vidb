# frozen_string_literal: true

require 'json'

begin
  raise ArgumentError, 'This read-only preview accepts no arguments' unless ARGV.empty?

  database = ActiveRecord::Base.connection_db_config.database
  unless Rails.env.production? && database == 'vidb_production'
    raise ArgumentError, 'Production vidb_production required'
  end

  root = '/videos'
  VideoAssets::ReconciliationVolumeGuard.new(root: root).call
  report = Record.transaction do
    Record.connection.execute('SET TRANSACTION READ ONLY')
    planner = VideoAssets::RelocationPlanner.new(root: root)
    counts = Hash.new(0)
    plans = []
    blocked = []
    assets = VideoAsset.where(status: 'present').joins(:record)
                       .where(records: { record_kind: 'standalone_video' })
                       .where('last_known_path LIKE ?', '/videos/Films/%')
                       .includes(:language_version, record: %i[genders video_assets]).order(:id).limit(250).to_a
    scanned = 0
    assets.each do |asset|
      scanned += 1
      record = asset.record
      genres = record.genders.map(&:name).sort
      metadata = { record_id: record.id, asset_id: asset.id, french_title: record.french_title,
                   original_title: record.original_title, year: record.year, year_basis: record.year_basis,
                   year_evidence: record.year_evidence, genres: genres, abstract: record.abstract,
                   language: asset.language_version&.short_name, source: asset.last_known_path }
      begin
        plan = planner.call(asset: asset, genres: genres)
        canonical = asset.last_known_path == plan[:source] && plan[:source] == plan[:target]
        if canonical && plan.dig(:checks, :source_regular) && plan.dig(:checks, :size_matches)
          counts['already_canonical'] += 1
          next
        end
        claimed = VideoAsset.where(status: 'present', last_known_path: plan[:target]).where.not(id: asset.id).exists?
        journal = "/srv/vidb/shared/relocations/relocation-#{record.id}-#{asset.id}.jsonl"
        plan[:checks][:source_path_canonical] = asset.last_known_path == plan[:source]
        plan[:checks][:destination_unclaimed] = !claimed
        plan[:checks][:no_existing_journal] = !File.exist?(journal) && !File.symlink?(journal)
        plan[:ready] = plan[:checks].values.all?
        if plan[:ready]
          version = asset.language_version
          qualified = version && (version.silent? || %w[VF VO VOST VM VMST].include?(version.short_name))
          plans << { metadata: metadata, plan: plan,
                     qualification_checks: { year_reference_confirmed: %w[first_release production].include?(record.year_basis),
                                             copy_language_qualified: !!qualified },
                     metadata_review_required: true, execution_authorized: false }
          counts['technical_candidate'] += 1
        else
          reasons = plan[:checks].select { |_, value| !value }.keys
          reasons.each { |reason| counts[reason.to_s] += 1 }
          blocked << metadata.merge(blocking_checks: reasons) if blocked.size < 5
        end
      rescue ArgumentError, SystemCallError => e
        counts['invalid_or_unreadable'] += 1
        blocked << metadata.merge(error_class: e.class.name, error: e.message) if blocked.size < 5
      end
      break if plans.size >= 5
    end
    { format: 'vidb.relocation_batch_preview', version: 1, mode: 'preview_only', execution_authorized: false,
      environment: Rails.env.to_s, database: database, root: root, generated_at: Time.current.iso8601,
      scan_limit: 250, scanned: scanned, selected: plans.size, counts: counts,
      more_may_remain: scanned < assets.size || assets.size == 250, plans: plans, blocked_examples: blocked,
      filesystem_changed: false, database_changed: false }
  end
  puts JSON.pretty_generate(report)
rescue StandardError => e
  warn JSON.pretty_generate(status: 'preview_failed', error_class: e.class.name, error: e.message)
  exit 1
end
