module ReconciliationWorkbench
  class StructurePlan
    def self.for(record)
      new(record).call
    end

    def initialize(record)
      @record = record
    end

    def call
      return unless @record.ancestry.to_s.split('/').size == 2

      root = @record.ancestors.first
      return unless root.root? && %w[series undetermined].include?(root.record_kind)
      return unless root.children.all? { |season| valid_season?(season) }

      records = [root, *root.descendants.order(:id).to_a]
      return unless records.any?(&:record_kind_undetermined?)

      payload(root, records)
    end

    private

    def valid_season?(season)
      return false unless %w[season undetermined].include?(season.record_kind) && season.has_children?
      return false unless season.rank.to_i.positive? || season.french_title.to_s.match?(/\ASaison\s+\d+\b/i)

      children = season.children.to_a
      children.all? { |child| valid_episode?(child) } && children.map(&:rank).uniq.size == children.size
    end

    def valid_episode?(record)
      %w[episode undetermined].include?(record.record_kind) && !record.has_children? && record.rank.to_i.positive?
    end

    def payload(root, records)
      roles = records.to_h do |record|
        [record.id.to_s, %w[series season episode].fetch(record.ancestry.to_s.split('/').size)]
      end
      { 'record_id' => root.id, 'title' => root.complete_title,
        'roles' => roles, 'records' => records.to_h { |item| [item.id.to_s, Snapshot.record(item)] },
        'reason' => 'Liens déjà présents dans vidb, saisons explicites et rangs d’épisodes uniques.',
        'file_count' => 0, 'paths' => [] }
    end
  end
end
