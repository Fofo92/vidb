# frozen_string_literal: true

require 'uri'

module CatalogEnrichment
  class ReviewedClassificationProposal
    def initialize(root: '/videos', path_builder: nil)
      @root = File.expand_path(root)
      @path_builder = path_builder || VideoAssets::RelocationPathBuilder.new(root: @root)
    end

    def call(record:, category:, genres:, known_genres:, evidence:)
      validate_classification!(category, genres)
      validate_evidence!(evidence)
      genres = canonical_genres(genres, known_genres)
      storage_genres = genres.map { |name| name == 'Biopic' ? 'Biographie' : name }
      film_path = @path_builder.call(record: record, genres: storage_genres)
      target = category == 'film' ? film_path : File.join(@root, 'Documentaires', File.basename(film_path))
      proposal(category, genres, known_genres, target, evidence)
    end

    private

    def canonical_genres(genres, known_genres)
      names = genres.map do |name|
        name == 'Biographie' && known_genres.include?('Biopic') ? 'Biopic' : name
      end
      raise ArgumentError, 'Duplicate canonical genres' unless names.uniq == names

      names
    end

    def validate_classification!(category, genres)
      raise ArgumentError, 'Unknown classification category' unless %w[film documentary].include?(category)
      raise ArgumentError, 'One or two distinct genres required' unless valid_genres?(genres)
      if category == 'documentary' && genres != ['Documentaire']
        raise ArgumentError, 'Documentary classification requires Documentaire'
      end
      return unless category == 'film' && genres.include?('Documentaire')

      raise ArgumentError, 'Documentaire requires documentary category'
    end

    def valid_genres?(genres)
      genres.is_a?(Array) && genres.size.between?(1, 2) && genres.uniq == genres &&
        genres.all? { |name| name.is_a?(String) && name == name.strip && !name.empty? }
    end

    def validate_evidence!(evidence)
      reason = evidence.fetch(:reason)
      sources = evidence.fetch(:sources)
      raise ArgumentError, 'Missing classification reason' unless reason.is_a?(String) && !reason.strip.empty?
      return if sources.is_a?(Array) && !sources.empty? && sources.all? { |source| valid_source?(source) }

      raise ArgumentError, 'HTTPS evidence sources required'
    end

    def proposal(category, genres, known_genres, target, evidence)
      missing_genres = genres - known_genres
      { policy: 'reviewed_classification_v1', category: category, genres: genres.sort,
        target: target, reason: evidence.fetch(:reason), sources: evidence.fetch(:sources).uniq,
        missing_genres: missing_genres.sort, references_available: missing_genres.empty?,
        status: missing_genres.empty? ? 'documented_proposal' : 'missing_genre_reference',
        execution_authorized: false }
    end

    def valid_source?(source)
      return false unless source.is_a?(String)

      uri = URI.parse(source)
      uri.scheme == 'https' && uri.host && !uri.host.empty? && uri.userinfo.nil?
    rescue URI::InvalidURIError
      false
    end
  end
end
