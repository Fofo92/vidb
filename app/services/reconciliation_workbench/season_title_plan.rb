module ReconciliationWorkbench
  class SeasonTitlePlan
    def call
      ReconciliationCase.transaction do
        origins.group_by { |origin| origin.fetch('root_id') }.filter_map do |root_id, receipts|
          propose(root_id, receipts)
        end
      end
    end

    private

    def origins
      ReconciliationCase.where(rule_key: Rules::SOURCED_STRUCTURE.key, status: 'applied').flat_map do |item|
        operations = item.payload.fetch('operations', [])
        receipts = item.result.fetch('episodes', [])
        next [] unless operations.size == receipts.size

        operations.zip(receipts).filter_map do |operation, receipt|
          next if operation['season_id'] || !receipt['season_id']

          { 'root_id' => item.payload.fetch('record_id'), 'season_id' => receipt.fetch('season_id'),
            'source_case_id' => item.id }
        end
      end
    end

    def propose(root_id, receipts)
      root = Record.find_by(id: root_id)
      return unless root&.record_kind_series?

      seasons = root.children.where(id: receipts.pluck('season_id').uniq).order(:id).lock.select do |season|
        season.record_kind_season? && season.rank.to_i.positive? &&
          season.french_title == format('Saison %02d', season.rank) &&
          season.french_title != "Saison #{season.rank}"
      end
      return if seasons.empty?

      CaseStore.propose(rule: Rules::SEASON_TITLES, key: "root:#{root.id}",
                        payload: payload(root, seasons, receipts), preserve_pending: true)
    end

    def payload(root, seasons, receipts)
      { 'record_id' => root.id, 'title' => root.complete_title, 'file_count' => 0,
        'records' => [root, *seasons].to_h { |record| [record.id.to_s, Snapshot.record(record)] },
        'source_case_ids' => receipts.select { |receipt| seasons.map(&:id).include?(receipt['season_id']) }
                                     .pluck('source_case_id').uniq.sort,
        'season_titles' => seasons.to_h do |season|
          [season.id.to_s,
           { 'before' => season.french_title, 'after' => "Saison #{season.rank}", 'rank' => season.rank }]
        end }
    end
  end
end
