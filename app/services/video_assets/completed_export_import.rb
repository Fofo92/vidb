# frozen_string_literal: true

module VideoAssets
  # Attaches an observed completed export to one already identified episode.
  class CompletedExportImport
    def initialize(observation, export)
      @observation = observation
      @export = export
    end

    def call
      Record.transaction do
        lock_import
        record = Record.find(@observation.fetch(:candidates).sole.fetch(:record_id))
        record.lock!
        validate_record!(record)
        validate_file!
        existing = VideoAsset.find_by(last_known_path: @observation.fetch(:path))
        return existing_result(existing, record) if existing

        CompletedExportRelocation.new(record, @observation, @export).call || attach!(record)
      end
    end

    private

    def attach!(record)
      asset = create_asset(record)
      confirm_default_unseen(record)
      minutes = asset.duration_minutes
      record.update!(length_in_mn: minutes) if record.length_in_mn.nil? && minutes.between?(10, 240)
      { status: 'imported', record_id: record.id, video_asset_id: asset.id,
        language: asset.language_version&.short_name }
    end

    def confirm_default_unseen(record)
      return unless record.effective_state(:is_seen).nil?

      # Import must not revalidate unrelated legacy catalogue metadata.
      now = Time.current
      record.update_columns(is_seen: false, seen_state_confirmed_at: now, updated_at: now)
    end

    def lock_import
      return unless Record.connection.adapter_name == 'PostgreSQL'

      Record.connection.execute('SELECT pg_advisory_xact_lock(20261011, 1)')
    end

    def validate_record!(record)
      candidate = @observation.fetch(:candidates).sole
      parent = record.parent
      raise ArgumentError, 'Placement non qualifié' unless qualified?(record, parent)

      fields = %i[ancestry rank french_title original_title]
      raise ArgumentError, 'Fiche modifiée depuis le rapprochement' unless fields.all? do |field|
        record.public_send(field) == candidate[field]
      end
    end

    def qualified?(record, parent)
      return false unless record.children.empty? && record.hierarchy_placement_status == :consistent
      return true if record.record_kind_standalone_video?

      record.record_kind_episode? && parent&.record_kind_season? && parent.parent&.record_kind_series?
    end

    def validate_file!
      stat = File.stat(@observation.fetch(:path))
      raise ArgumentError, 'Fichier modifié avant import' unless [stat.size, stat.mtime,
                                                                  stat.ino] == @export[:signature]
    end

    def existing_result(asset, record)
      expected = @export.fetch(:receipt)
      recorded = asset.technical_details['video_encoder_export']
      same_copy = asset.status_present? && asset.record_id == record.id && recorded == expected
      return { status: 'already_imported', video_asset_id: asset.id } if same_copy &&
                                                                         asset.byte_size == expected['byte_size']

      raise ArgumentError, 'Chemin déjà enregistré avec une autre copie'
    end

    def create_asset(record)
      receipt = @export.fetch(:receipt)
      details = @export.fetch(:details).merge('video_encoder_export' => receipt)
      version = language(details, receipt)
      VideoAsset.create!(record: record, status: 'present', last_known_path: @observation.fetch(:path),
                         byte_size: receipt.fetch('byte_size'),
                         duration_minutes: [(@export[:seconds] / 60).round, 1].max,
                         observed_at: Time.current, medium: Medium.find_by!(short_name: 'HD'),
                         language_version: version && LanguageVersion.find_by!(short_name: version),
                         container: details.dig('format', 'format_name'), technical_details: details)
    end

    def language(details, receipt)
      roles = receipt.fetch('roles')
      evidence = { status: 'matched', original_role_complete: roles.include?('original'),
                   french_role_complete: roles.include?('french') }
      EncoderLanguageProposal.new(details.fetch('streams'), evidence).call
    end
  end
end
