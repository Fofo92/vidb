# frozen_string_literal: true

module VideoAssets
  class BatchImport
    def initialize(evidence:, observer: BatchFileObservation.new)
      @evidence = evidence.deep_symbolize_keys
      @candidates = BatchCandidates.new(@evidence)
      @observer = observer
    end

    def call(apply: false)
      observations = @candidates.entries.map { |entry| @observer.call(entry) }
      VideoAsset.transaction do
        lock_records!
        @candidates.verify!
        plans = @candidates.entries.zip(observations).map { |entry, observed| plan(entry, observed) }
        observations.each { |observed| @observer.verify!(observed) }
        plans.each { |asset, attributes| asset.update!(attributes) } if apply
        report(plans, apply)
      end
    end

    private

    def lock_records!
      ids = @candidates.entries.flat_map do |entry|
        candidate = entry.fetch(:candidate)
        [candidate.fetch(:record_id), *candidate[:ancestry].to_s.split('/').map(&:to_i)]
      end
      @records = Record.where(id: ids.uniq).order(:id).lock.to_a.index_by(&:id)
    end

    def plan(entry, observed)
      record = @records.fetch(entry.fetch(:candidate).fetch(:record_id))
      raise ArgumentError, "Record is not a leaf: #{record.id}" if record.has_children?

      asset = existing_or_new(record, entry.fetch(:path))
      validate_observation!(entry, observed)
      [asset, attributes(asset, observed)]
    end

    def existing_or_new(record, path)
      present = VideoAsset.where(status: 'present').where('record_id = ? OR last_known_path = ?', record.id, path)
      assets = present.order(:id).lock.to_a
      valid = assets.empty? || same_copy?(assets, record, path)
      raise ArgumentError, "Conflicting present copy for record #{record.id}" unless valid

      assets.first || VideoAsset.new(record: record, last_known_path: path, status: 'present')
    end

    def same_copy?(assets, record, path)
      assets.one? && assets.first.record_id == record.id && assets.first.last_known_path == path
    end

    def validate_observation!(entry, observed)
      storage = observed.fetch(:technical_details).fetch('storage')
      valid = observed.fetch(:path) == entry.fetch(:path) && observed.fetch(:byte_size) == entry.fetch(:size)
      valid &&= storage.fetch('uuid') == @evidence.fetch(:storage_uuid)
      raise ArgumentError, "File or volume differs: #{entry.fetch(:path)}" unless valid
    end

    def attributes(asset, observed)
      medium = Medium.find_by!(short_name: @evidence.fetch(:medium))
      raise ArgumentError, 'Existing support conflicts with batch' if asset.medium_id && asset.medium_id != medium.id

      observed.slice(:byte_size, :duration_minutes, :container, :observed_at).merge(
        medium_id: medium.id, technical_details: technical_details(asset, observed)
      )
    end

    def technical_details(asset, observed)
      asset.technical_details.merge(observed.fetch(:technical_details)).merge(
        'measured_duration_seconds' => observed.fetch(:measured_duration_seconds),
        'observed_at' => observed.fetch(:observed_at).iso8601,
        'reconciliation' => @evidence.slice(:source_inventory, :selection_policy).deep_stringify_keys
      )
    end

    def report(plans, apply)
      { applied: apply, total: plans.size, copies: plans.map do |asset, attributes|
        attributes.merge(record_id: asset.record_id, video_asset_id: asset.id, path: asset.last_known_path)
      end }
    end
  end
end
