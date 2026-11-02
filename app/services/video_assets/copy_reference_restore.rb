# frozen_string_literal: true

module VideoAssets
  # Operator-only recovery; defaults to a preview and never restores Record flags.
  class CopyReferenceRestore
    def call(path, apply: false)
      rows = CopyReferenceBackup.read(path).fetch('assets')
      validate(rows)
      if apply
        VideoAsset.transaction do
          lock_tables
          validate(rows)
          rows.each { |attributes| VideoAsset.create!(attributes) }
        end
      end
      { applied: apply, video_asset_ids: rows.pluck('id') }
    end

    private

    def lock_tables
      connection = VideoAsset.connection
      return unless connection.adapter_name == 'PostgreSQL'

      connection.execute('SELECT pg_advisory_xact_lock(20261011, 1)')
      connection.execute('LOCK TABLE records IN SHARE ROW EXCLUSIVE MODE')
      connection.execute('LOCK TABLE video_assets IN SHARE ROW EXCLUSIVE MODE')
    end

    def validate(rows)
      raise ArgumentError, 'Lot de restauration invalide.' unless rows.size.between?(1, 100)

      rows.each { |row| validate_row(row) }
      ids = rows.pluck('id')
      raise ArgumentError, 'Identifiants répétés dans la sauvegarde.' unless ids.uniq.size == ids.size
      raise ArgumentError, 'Un identifiant de copie est déjà utilisé.' if VideoAsset.where(id: ids).exists?
      raise ArgumentError, 'Un chemin est déjà associé à une copie.' if
        VideoAsset.where(last_known_path: rows.pluck('last_known_path')).exists?
    end

    def validate_row(row)
      valid = row.is_a?(Hash) && (row.keys - VideoAsset.column_names).empty?
      valid &&= row['id'].is_a?(Integer) && row['id'].positive? && Record.exists?(id: row['record_id'])
      valid &&= %w[missing deleted].include?(row['status'])
      raise ArgumentError, 'Copie incompatible ou œuvre disparue : restauration refusée.' unless valid
    end
  end
end
