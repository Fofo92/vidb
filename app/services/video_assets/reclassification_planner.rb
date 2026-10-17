# frozen_string_literal: true

module VideoAssets
  class ReclassificationPlanner < RelocationPlanner
    def initialize(root:, classification:, volume_guard: nil)
      @classification = classification.deep_dup
      @classifier = CatalogEnrichment::ReviewedClassificationProposal.new(root: root)
      super(root: root, builder: method(:classification_target), volume_guard: volume_guard)
    end

    def call(asset:, genres:)
      plan = super
      plan[:checks][:genre_provenance_unqualified] = asset.record.genre_provenance.empty?
      plan[:checks][:proposed_genres_available] = @proposal.fetch(:references_available)
      plan[:checks][:proposed_genres_unambiguous] = unambiguous_genres?
      plan[:checks][:target_without_json] = no_adjacent_json?(Pathname.new(plan.fetch(:target)))
      plan[:classification] = @proposal.deep_dup
      plan[:ready] = plan[:checks].values.all?
      plan
    end

    private

    def classification_target(record:, genres:)
      raise ArgumentError, 'Current genres changed' unless record.genders.reload.map(&:name).sort == genres.sort

      @proposal = @classifier.call(record: record, category: @classification.fetch(:category),
                                   genres: @classification.fetch(:genres), known_genres: Gender.pluck(:name),
                                   evidence: @classification.fetch(:evidence))
      @proposal.fetch(:target)
    end

    def unambiguous_genres?
      names = Gender.where(name: @proposal.fetch(:genres)).pluck(:name)
      names.sort == @proposal.fetch(:genres).sort
    end

    def path_checks(source, target)
      super.except(:same_directory).merge(
        different_directories: source.dirname != target.dirname,
        same_device: same_device?(source, target)
      )
    end

    def same_device?(source, target)
      return false unless safe_ancestors?(source) && safe_ancestors?(target)

      File.lstat(source.dirname).dev == File.lstat(target.dirname).dev
    rescue SystemCallError
      false
    end
  end
end
