# frozen_string_literal: true

require "json"
require "fileutils"

abort "Usage: bin/rails runner script/reconciliation_consolidation_cases.rb SHARED_DIRECTORY" unless ARGV.length == 1

directory = Pathname.new(ARGV.fetch(0))
followup = JSON.parse(directory.join("reconciliation-followup/current.json").read)
exceptions_path = directory.join("films-language-exceptions.json")
language_exceptions = exceptions_path.file? ? JSON.parse(exceptions_path.read) : []
# Keep only linguistic exceptions which are still unqualified present copies.
ids = language_exceptions.filter_map { |item| item["video_asset_id"] }
pending_ids = VideoAsset.where(id: ids, status: "present", language_version_id: nil).pluck(:id)
language_exceptions.select! { |item| pending_ids.include?(item["video_asset_id"]) }
result = VideoAssets::ConsolidationCases.new(followup: followup, language_exceptions: language_exceptions).call

json_path = directory.join("reconciliation-consolidation-cases.json")
markdown_path = directory.join("reconciliation-consolidation-cases.md")
json_path.write(JSON.pretty_generate(result) + "\n")

lines = ["# Cas à consolider", "", "Inventaire : #{result.fetch(:inventory_at)}", "",
         "#{result.fetch(:case_count)} dossiers à traiter. Les volumes comptent des fichiers, pas des décisions.", "",
         "Les exceptions linguistiques concernent des copies déjà rattachées.", ""]
result.fetch(:cases).each do |item|
  lines += ["## #{item[:case_number]}. #{item[:directory]}", "", "#{item[:file_count]} fichiers concernés.", "",
            "Motifs : #{item[:categories].map { |name, count| "#{VideoAssets::ConsolidationCases::LABELS.fetch(name, name)} : #{count}" }.join(", ")}.", ""]
  lines += item[:actions].map { |action| "- #{action}" }
  lines += ["", "Fiches candidates : #{item[:record_ids].first(20).join(", ")}", "",
            "Exemples :", ""]
  lines += item[:paths].first(3).map { |path| "- #{path}" }
  lines << ""
end
markdown_path.write(lines.join("\n") + "\n")
puts JSON.pretty_generate(result.slice(:inventory_at, :case_count, :file_counts))
puts json_path
puts markdown_path
