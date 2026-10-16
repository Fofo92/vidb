# frozen_string_literal: true

# bin/rails runner script/qualify_355_genre.rb [--apply]
# --apply changes only the known genre classification in vidb_production.
# The subsequent filesystem/relocation preview is always read-only.
require 'json'

begin
  raise ArgumentError, 'Only --apply is accepted' unless ARGV.empty? || ARGV == ['--apply']

  connection = ActiveRecord::Base.connection
  database = ActiveRecord::Base.connection_db_config.database
  unless connection.adapter_name == 'PostgreSQL' && !connection.transaction_open?
    raise ArgumentError, 'Run outside an existing PostgreSQL transaction'
  end
  apply = ARGV == ['--apply']
  if apply && !(Rails.env.production? && database == 'vidb_production')
    raise ArgumentError, 'Applying this known correction requires vidb_production in production'
  end

  verify = lambda do |record, assets|
    unless record.french_title == '355' && record.original_title == 'The 355' && record.year == 2022 &&
           record.record_kind_standalone_video?
      raise ArgumentError, 'Record 3879 no longer matches the reviewed film'
    end
    allowed_paths = ['/videos/Films/Espionnage/355 (The 355)_vf.mkv',
                     '/videos/Films/Espionnage/355 (The 355) (2022).mkv']
    unless assets.size == 1 && assets.first.id == 1445 && allowed_paths.include?(assets.first.last_known_path)
      raise ArgumentError, 'The confirmed copy no longer matches the reviewed case'
    end
  end

  qualification = if apply
                    Record.transaction do
                      record = Record.lock.find(3879)
                      assets = record.video_assets.where(status: 'present').lock.to_a
                      verify.call(record, assets)
                      VideoAssets::GenreQualification.new.call(
                        record: record, names: ['Espionnage'], expected_names: %w[Action Aventure Thriller]
                      )
                    end
                  else
                    { changed: false, mode: 'preview_only' }
                  end

  report = Record.transaction do
    connection.execute('SET TRANSACTION READ ONLY')
    record = Record.find(3879)
    assets = record.video_assets.where(status: 'present').to_a
    verify.call(record, assets)
    genres = record.genders.pluck(:name)
    planner = VideoAssets::RelocationPlanner.new(root: '/videos')
    plans = assets.map do |asset|
      begin
        plan = planner.call(asset: asset, genres: genres)
        plan.merge(blocking_checks: plan.fetch(:checks).select { |_name, passed| !passed }.keys)
      rescue ArgumentError, SystemCallError => error
        { asset_id: asset.id, source: asset.last_known_path, ready: false,
          execution_authorized: false, error: error.message }
      end
    end
    { environment: Rails.env.to_s, database: database, qualification: qualification,
      record_id: record.id, genres: genres, plans: plans,
      filesystem_execution_authorized: false }
  end
  puts JSON.pretty_generate(report)
rescue StandardError => error
  warn JSON.pretty_generate(status: 'failed', error_class: error.class.name, error: error.message,
                            note: 'No video rename was attempted. If qualification committed, it remains applied.')
  exit 1
end
