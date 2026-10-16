# frozen_string_literal: true

require 'json'

begin
  raise ArgumentError, 'Usage: bin/rails runner script/qualify_355_language.rb [--apply]' unless [[], ['--apply']].include?(ARGV)

  database = ActiveRecord::Base.connection_db_config.database
  raise ArgumentError, 'This scoped operation requires vidb_production' unless Rails.env.production? && database == 'vidb_production'

  record = Record.find(3879)
  asset = record.video_assets.find(1445)
  expected_paths = ['/videos/Films/Espionnage/355 (The 355)_vf.mkv',
                    '/videos/Films/Espionnage/355 (The 355) (2022).mkv']
  valid = record.french_title == '355' && record.original_title == 'The 355' && record.year == 2022 &&
          record.record_kind_standalone_video? && record.genders.pluck(:name) == ['Espionnage'] &&
          expected_paths.include?(asset.last_known_path) && asset.status_present?
  raise ArgumentError, 'Film or copy no longer matches the reviewed case' unless valid

  result = VideoAssets::AutomaticLanguageQualification.new.call(asset_id: asset.id, apply: ARGV == ['--apply'])
  puts JSON.pretty_generate(result.merge(environment: Rails.env.to_s, database: database, filesystem_changed: false))
  exit 2 if result[:status] == 'needs_review'
rescue StandardError => e
  warn JSON.pretty_generate(status: 'failed', error_class: e.class.name, error: e.message)
  exit 1
end
