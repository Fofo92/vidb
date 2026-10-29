module Tv
  class LibraryEpisodeCandidates
    def initialize(records: Record)
      @records = records
    end

    def call(programmes)
      requests = programmes.filter_map do |programme|
        key = AcquiredEpisodeIdentity.key(programme)
        [programme, key] if key
      end
      return {} if requests.empty?

      names = requests.map { |_, key| key.first }.uniq
      roots = roots_by_name(names)
      positions = indexed_episodes(roots.values.flatten.uniq(&:id), requests)
      requests.to_h { |programme, key| [programme.id, candidate(programme, key, roots, positions)] }.compact
    end

    private

    def roots_by_name(names)
      @records.where(record_kind: 'series').select(:id, :ancestry, :french_title, :original_title)
              .each_with_object({}) do |root, index|
        (AcquiredEpisodeIdentity.titles(root) & names).each { |name| (index[name] ||= []) << root }
      end
    end

    def indexed_episodes(roots, requests)
      return {} if roots.empty?

      roots_by_path = roots.index_by { |root| child_ancestry(root) }
      seasons = seasons_for(roots_by_path.keys, requests)
      seasons_by_path = seasons.index_by { |season| child_ancestry(season) }
      episodes = @records.where(record_kind: 'episode', ancestry: seasons_by_path.keys,
                                rank: requests.map { |_, key| key[2] }.uniq).includes(:video_assets)
      episodes.group_by do |episode|
        season = seasons_by_path.fetch(episode.ancestry)
        [roots_by_path.fetch(season.ancestry).id, season.rank, episode.rank]
      end
    end

    def seasons_for(paths, requests)
      seasons = @records.where(record_kind: 'season', ancestry: paths,
                               rank: requests.map { |_, key| key[1] }.uniq)
      seasons.group_by { |season| [season.ancestry, season.rank] }.values.select(&:one?).map(&:first)
    end

    def child_ancestry(record)
      [record.ancestry.presence, record.id].compact.join('/')
    end

    def candidate(programme, key, roots, positions)
      matching_roots = roots.fetch(key.first, [])
      return unless matching_roots.one?

      rows = positions.fetch([matching_roots.first.id, key[1], key[2]], [])
      return unless rows.one?
      return unless AcquiredEpisodeIdentity.concordant?(programme, AcquiredEpisodeIdentity.titles(rows.first))

      rows.first
    end
  end
end
