# frozen_string_literal: true

module VideoAssets
  class ReclassificationCommit < RelocationCommit
    def initialize(qualification:, **options)
      raise ArgumentError, 'Explicit filesystem adapter required' unless options[:file_rename]

      @qualification = qualification.deep_dup
      super(**options, writer: method(:persist_classification_and_path!))
    end

    private

    def checked_preview(plan, asset, genres)
      verify_validation!(asset)
      verify_snapshots!(asset)
      @classification = classification_for(asset.record)
      current = super
      unless current.fetch(:classification) == @classification
        raise Refused, 'Classification differs from reviewed proposal'
      end

      current
    end

    def verify_validation!(asset)
      valid = [asset.record, asset].all? { |value| value.valid? && !value.has_changes_to_save? }
      raise Refused, 'Record or copy validation requires a separate correction' unless valid
    end

    def classification_for(record)
      CatalogEnrichment::ReviewedClassificationProposal.new(root: @root.to_s).call(
        record: record, category: @qualification.fetch(:category), genres: @qualification.fetch(:genres),
        known_genres: Gender.pluck(:name), evidence: @qualification.fetch(:evidence)
      )
    end

    def verify_snapshots!(asset)
      record = asset.record
      unchanged = record.attributes.except('updated_at').as_json == @qualification.fetch(:record_snapshot) &&
                  asset.attributes.except('updated_at').as_json == @qualification.fetch(:copy_snapshot)
      raise Refused, 'Reviewed metadata or copy changed' unless unchanged
      raise Refused, 'Genre provenance is protected' if record.genre_provenance.present?

      verify_genre_snapshot!(record)
    end

    def verify_genre_snapshot!(record)
      expected = @qualification.fetch(:expected)
      valid = record.genders.reload.map(&:name).sort == expected.fetch(:genres) &&
              record.genre_provenance == expected.fetch(:provenance) &&
              record.video_assets.where(status: 'present').one?
      raise Refused, 'Genre snapshot or present copy count changed' unless valid
    end

    def execute_locked(journal, plan, asset, genres)
      current = checked_preview(plan, asset, genres)
      payload = current.slice(:record_id, :asset_id, :source, :target, :identity)
      payload[:classification] = @classification
      payload[:qualification] = @qualification
      RelocationJournal.append(journal, 'prepared', payload)
      rename_and_verify!(journal, current)
      @writer.call(asset, current.fetch(:target))
    end

    def rename_and_verify!(journal, current)
      @renamer.call(source: current.fetch(:source), target: current.fetch(:target), identity: current.fetch(:identity))
      verify_rename!(current)
      record_physical_checkpoint(journal, current)
    end

    def record_physical_checkpoint(journal, current)
      after = RelocationFileIdentity.call(File.lstat(current.fetch(:target)))
      RelocationJournal.append(journal, 'filesystem_renamed', identity_after: after)
    end

    def validate_paths!(current, asset)
      source, target = %i[source target].map { |key| Pathname.new(current.fetch(key)) }
      unless volume_paths?(source, target) && scoped_paths?(source, target)
        raise Refused, 'Existing distinct directories on one volume required'
      end

      occupied = asset.class.where(last_known_path: target.to_s).where.not(id: asset.id).exists?
      raise Refused, 'Destination belongs to another copy' if occupied
    end

    def volume_paths?(source, target)
      @root.absolute? && [source, target].all? { |path| inside_root?(path) } &&
        source.dirname != target.dirname && File.lstat(source.dirname).dev == File.lstat(target.dirname).dev
    end

    def scoped_paths?(source, target)
      relative_source = source.relative_path_from(@root).each_filename.to_a
      relative_target = target.relative_path_from(@root).each_filename.to_a
      source_valid = relative_source.size == 3 && relative_source.first == 'Films'
      film = relative_target.size == 3 && relative_target.first == 'Films' && @classification[:category] == 'film'
      documentary = relative_target.size == 2 && relative_target.first == 'Documentaires' &&
                    @classification[:category] == 'documentary'
      source_valid && (film || documentary)
    end

    def persist_classification_and_path!(asset, target)
      result = CatalogEnrichment::ReviewedGenreApplication.new.call(
        record: asset.record, genres: @classification.fetch(:genres), expected: @qualification.fetch(:expected),
        evidence: @qualification.fetch(:evidence), operation_id: @qualification.fetch(:operation_id)
      )
      raise Refused, "Genre qualification refused: #{result[:status]}" unless result[:status] == 'applied'

      asset.update!(last_known_path: target)
      verify_preserved_metadata!(asset)
    end

    def verify_preserved_metadata!(asset)
      record_columns = %w[updated_at genre_provenance]
      copy_columns = %w[updated_at last_known_path]
      valid = asset.record.reload.attributes.except(*record_columns).as_json ==
              @qualification.fetch(:record_snapshot).except('genre_provenance') &&
              asset.reload.attributes.except(*copy_columns).as_json ==
              @qualification.fetch(:copy_snapshot).except('last_known_path')
      raise Refused, 'Unrelated metadata changed during reclassification' unless valid
    end
  end
end
