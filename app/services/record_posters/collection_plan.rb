# frozen_string_literal: true

module RecordPosters
  # Conservative consensus: every local child, two distinct films and a matching collection title.
  class CollectionPlan
    def initialize(client:)
      @client = client
    end

    def call(record)
      return report('review', 'La fiche n’est pas une collection') unless record.record_kind == 'collection'

      return report('preserved', 'Pochette déjà conservée') if Fetch.preserved?(record.record_poster)

      explicit = Evidence.ids(record, 'collection')
      return report('review', 'Références de collection contradictoires') if explicit.many?
      return report('identified', 'Référence déjà établie', target: explicit.first) if explicit.one?

      inferred(record)
    end

    private

    def inferred(record)
      children = record.children.to_a
      return report('review', 'Enfants non identifiés ou structure composite') unless qualified?(children)

      movies = children.map { |child| Evidence.ids(child, 'movie').sole }.uniq.sort
      return report('review', 'Deux films distincts identifiés sont nécessaires') if movies.size < 2

      memberships = movies.map { |id| @client.movie(id)['belongs_to_collection'] }
      return report('review', 'Appartenances absentes ou divergentes') unless unanimous?(memberships)

      candidate(record, movies, memberships.first.fetch('id'))
    end

    def qualified?(children)
      children.any? && children.all? do |child|
        child.record_kind == 'standalone_video' && !child.has_children? && Evidence.ids(child, 'movie').one?
      end
    end

    def unanimous?(memberships)
      memberships.all? { |item| item.is_a?(Hash) && item['id'].is_a?(Integer) && item['id'].positive? } &&
        memberships.map { |item| item['id'] }.uniq.one?
    end

    def candidate(record, movies, id)
      collection = @client.collection(id)
      parts = collection.fetch('parts').filter_map { |part| part['id'] if part.is_a?(Hash) }
      return report('review', 'Catalogue TMDB incompatible', target: id) unless (movies - parts).empty?
      return report('review', 'Titre de collection à confirmer', target: id) unless matching_title?(record, collection)

      report('ready', 'Appartenances et titre concordants', target: id, movies: movies)
    end

    def matching_title?(record, collection)
      local = [record.french_title, record.original_title].filter_map { |title| title_key(title).presence }
      remote = [collection['name'], collection['original_name']].filter_map { |title| title_key(title).presence }
      local.intersect?(remote)
    end

    def title_key(value)
      value.to_s.parameterize.split('-').reject { |word| %w[collection saga integrale].include?(word) }.join('-')
    end

    def report(status, reason, **details)
      { status: status, reason: reason }.merge(details)
    end
  end
end
