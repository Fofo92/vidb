# frozen_string_literal: true

# Usage: bin/rails runner script/video_asset_relocation_preview.rb [RECORD_ID]
# Without RECORD_ID, select the exact French title '355', only if unique.
# PostgreSQL enforces a read-only transaction. Output goes to stdout only.

require 'json'

begin
  unless ARGV.size <= 1 && (ARGV.empty? || ARGV.first.match?(/\A[1-9]\d*\z/))
    raise ArgumentError, 'Usage: bin/rails runner script/video_asset_relocation_preview.rb [RECORD_ID]'
  end

  connection = ActiveRecord::Base.connection
  raise ArgumentError, 'This preview requires PostgreSQL' unless connection.adapter_name == 'PostgreSQL'
  raise ArgumentError, 'Run this script outside an existing transaction' if connection.transaction_open?

  report = ActiveRecord::Base.transaction do
    connection.execute('SET TRANSACTION READ ONLY')
    context = {
      mode: 'preview_only', execution_authorized: false,
      environment: Rails.env.to_s,
      database: ActiveRecord::Base.connection_db_config.database,
      root: '/videos', generated_at: Time.current.iso8601
    }
    scope = ARGV.empty? ? Record.where(french_title: '355') : Record.where(id: ARGV.first.to_i)
    matches = scope.order(:id).limit(2).to_a

    if matches.empty?
      context.merge(status: 'record_not_found', selection: ARGV.first || '355')
    elsif matches.size > 1
      context.merge(status: 'ambiguous_record',
                    candidates: matches.map { |record| { id: record.id, title: record.french_title } })
    else
      record = matches.first
      genres = record.genders.pluck(:name)
      assets = record.video_assets.where(status: 'present').order(:id).to_a
      planner = VideoAssets::RelocationPlanner.new(root: '/videos')
      plans = assets.map do |asset|
        begin
          plan = planner.call(asset: asset, genres: genres)
          plan.merge(blocking_checks: plan.fetch(:checks).select { |_name, passed| !passed }.keys)
        rescue ArgumentError, SystemCallError => error
          { asset_id: asset.id, source: asset.last_known_path, ready: false,
            execution_authorized: false, error_class: error.class.name, error: error.message }
        end
      end
      status = if assets.empty?
                 'no_present_copy'
               elsif assets.size == 1 && plans.first[:ready]
                 'preview_ready'
               else
                 'blocked'
               end
      context.merge(
        status: status,
        record: { id: record.id, french_title: record.french_title, original_title: record.original_title,
                  year: record.year, kind: record.record_kind, seen: record.is_seen?, genres: genres },
        present_copy_count: assets.size, plans: plans
      )
    end
  end
  puts JSON.pretty_generate(report)
rescue StandardError => error
  warn JSON.pretty_generate(status: 'preview_error', execution_authorized: false,
                            error_class: error.class.name, error: error.message)
  exit 1
end
