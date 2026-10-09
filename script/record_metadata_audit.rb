# frozen_string_literal: true

require "json"

abort "Usage: bin/rails runner script/record_metadata_audit.rb DIRECTORY" unless ARGV.length == 1

directory = Pathname.new(ARGV.fetch(0))
audit = RecordMetadataAudit.new.call
directory.join("record-metadata-audit.json").write(JSON.pretty_generate(audit) + "\n")
lines = ["# Fiches à compléter ou consolider", "", "#{audit[:to_work]} fiches sur #{audit[:total]}.", "",
         "| ID | Titre | Manques | À consolider |", "|---|---|---|---|"]
audit[:records].each do |row|
  title = row[:title].to_s.gsub("|", "\\|").gsub(/\r?\n/, " ")
  missing = row[:missing].map { |field| RecordMetadataAudit::LABELS.fetch(field) }.join(", ")
  lines << "| #{row[:id]} | #{title} | #{missing} | #{row[:review].join(', ')} |"
end
directory.join("record-metadata-audit.md").write(lines.join("\n") + "\n")
puts JSON.pretty_generate(audit.except(:records))
puts directory.join("record-metadata-audit.md")
