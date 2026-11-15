# frozen_string_literal: true

require 'digest'
require 'json'

# This operation is deliberately restricted to the eight inspected DVD projects.
root = Pathname.new('/videos/Séries TV/Code Quantum (1989) (Quantum Leap) (1989)/Saison 02')
apply = ENV['VIDB_DVD_BACKFILL_APPLY'] == '1'

Record.transaction do
  Record.connection.execute('SET TRANSACTION READ ONLY') unless apply
  edition = DvdEdition.find_by!(ean: '5050582454376', record_id: 15106)
  projects = root.glob('*.json').reject { |path| path.to_s.end_with?('.video_encoder-export.json') }
  rows = projects.filter_map do |path|
    document = JSON.parse(path.read)
    identity = document.dig('vidb', 'record_id')
    next unless (15117..15124).include?(identity)

    raise "Origine DVD absente : #{path}" unless document.dig('dvd', 'profile') == 'dvd-pal-hevc-v1'
    record = Record.find(identity)
    unless record.record_kind_episode? && record.parent_id == 15108 && record.rank == identity - 15116
      raise "Fiche déplacée ou renumérotée : #{identity}"
    end
    output = path.sub_ext('.mkv')
    receipt = JSON.parse(Pathname.new("#{output}.video_encoder-export.json").read)
    checks = [
      receipt['project_sha256'] == Digest::SHA256.file(path).hexdigest,
      receipt['project_id'] == document.fetch('project_id'),
      receipt.dig('vidb', 'record_id') == identity,
      receipt['project_path'] == path.to_s,
      receipt['output_path'] == output.to_s,
      output.file? && receipt['byte_size'] == output.size
    ]
    raise "Reçu d’export non concordant : #{path}" unless checks.all?

    { record: record, project: path.to_s }
  end
  unless rows.map { |row| row[:record].id }.sort == (15117..15124).to_a
    raise 'Les huit projets attendus doivent être présents une seule fois.'
  end

  rows.each { |row| DvdOwnership.confirm!(edition: edition, record: row[:record]) } if apply
  puts JSON.pretty_generate(
    mode: apply ? 'appliqué' : 'aperçu en lecture seule',
    ean: edition.ean,
    episodes: rows.map { |row| { fiche: row[:record].id, projet: row[:project] } },
    nombre: rows.size,
    fichiers_modifies: 0
  )
end
