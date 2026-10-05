# frozen_string_literal: true

module VideoAssets
  # Proposes episodes using an observed directory hierarchy, without database writes.
  class EpisodeMatcher
    NUMBER = /\A\s*(?:S(?<season>\d+)\s*)?(?:E|[ÉE]pisode\s+)(?<episode>\d+)\b/i
    SEASON = /\ASaison\s+(\d+)\b/i

    def initialize(records)
      @by_id = records.to_a.index_by(&:id)
      @children = @by_id.values.group_by { |record| record.ancestry.to_s.split('/').last&.to_i }
      @container_matcher = ContainerMatcher.new(@by_id.values)
    end

    def match(entry)
      number = NUMBER.match(entry[:stem].to_s)
      return deferred('episode_number_unrecognized') unless number

      context = directory_context(entry, number)
      return deferred(context[:reason]) if context[:reason]

      match_container(entry, number, context)
    end

    private

    def directory_context(entry, number)
      directories = File.dirname(entry[:relative_path].to_s).split('/').map(&:strip)
      directory_number = SEASON.match(directories.last.to_s)&.[](1)&.to_i
      season = number[:season]&.to_i || directory_number
      {
        season: season,
        container: directory_number ? directories[-2] : directories.last,
        reason: number_conflict(entry, number, season, directory_number)
      }
    end

    def number_conflict(entry, number, season, directory_number)
      return 'season_number_conflict' if directory_number && directory_number != season
      return 'inventory_number_conflict' if inventory_conflict?(entry, number, season)

      nil
    end

    def inventory_conflict?(entry, number, season)
      metadata = entry[:episode] || {}
      episode_conflict = metadata[:episode] && metadata[:episode].to_i != number[:episode].to_i
      season_conflict = metadata[:season] && season && metadata[:season].to_i != season
      episode_conflict || season_conflict
    end

    def match_container(entry, number, context)
      container = @container_matcher.match(context[:container].to_s)
      if container[:reason]
        return deferred(container[:reason]).merge(
          container_candidates: container[:container_candidates]
        )
      end

      roots = container[:roots]
      parents = context[:season] ? seasons_for(roots.first, context[:season]) : roots
      match_parent(entry, number, parents)
    end

    def match_parent(entry, number, parents)
      return deferred('season_unmatched') if parents.empty?
      return deferred('season_ambiguous') if parents.many?

      episodes = children_of(parents.first).select do |record|
        record.rank == number[:episode].to_i &&
          %w[episode undetermined].include?(record.record_kind) && children_of(record).empty?
      end
      result(entry, number, episodes)
    end

    def children_of(record)
      @children.fetch(record.id, [])
    end

    def seasons_for(root, number)
      children_of(root).select do |record|
        %w[season undetermined].include?(record.record_kind) &&
          children_of(record).any? && season_number_matches?(record, number)
      end
    end

    def season_number_matches?(record, number)
      title_number = SEASON.match(record.french_title.to_s)&.[](1)&.to_i
      return false if record.rank && record.rank != number
      return false if title_number && title_number != number

      record.rank == number || title_number == number
    end

    def result(entry, number, episodes)
      return deferred('episode_unmatched') if episodes.empty?

      candidates = episodes.map { |record| candidate(record) }
      return { status: 'ambiguous_episode', candidates: candidates } if episodes.many?

      title = entry[:stem].to_s[number.end(0)..].sub(/\A\s*[-—–]\s*/, '').strip
      EpisodeTitleMatcher.call(episodes.first, title, number[:episode].to_i)
                         .merge(candidates: candidates)
    end

    def candidate(record)
      TitleMatcher.new([record]).match(record.complete_title)[:candidates].first.merge(
        ancestors: record.ancestry.to_s.split('/').filter_map do |id|
          ancestor = @by_id[id.to_i]
          { record_id: ancestor.id, title: ancestor.complete_title } if ancestor
        end
      )
    end

    def deferred(reason)
      { status: 'deferred_episode', reason: reason, candidates: [] }
    end
  end
end
