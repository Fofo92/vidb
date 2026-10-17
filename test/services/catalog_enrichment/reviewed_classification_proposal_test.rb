# frozen_string_literal: true

require 'test_helper'

class ReviewedClassificationProposalTest < ActiveSupport::TestCase
  Film = Struct.new(:french_title, :original_title, :year, :seen, keyword_init: true) do
    def record_kind_standalone_video?
      true
    end

    def is_seen?
      seen
    end
  end

  setup do
    @record = Film.new(french_title: 'Exemple', original_title: 'Example', year: 2023, seen: false)
    @service = CatalogEnrichment::ReviewedClassificationProposal.new
    @arguments = { record: @record, category: 'film', genres: ['Drame'], known_genres: ['Drame'],
                   evidence: { reason: 'Qualification documentée.', sources: ['https://example.org/film'] } }
  end

  test 'film path follows the existing naming convention' do
    result = @service.call(**@arguments)
    assert_equal '/videos/Films/Drame/Exemple (Example) (2023).mkv', result[:target]
    assert_equal 'documented_proposal', result[:status]
    assert_equal false, result[:execution_authorized]
  end

  test 'documentary category selects the documentary branch' do
    result = @service.call(**@arguments.merge(category: 'documentary', genres: ['Documentaire'], known_genres: ['Documentaire']))
    assert_equal '/videos/Documentaires/Exemple (Example) (2023).mkv', result[:target]
    assert result[:references_available]
  end

  test 'seen prefix survives a documentary classification' do
    @record.seen = true
    result = @service.call(**@arguments.merge(category: 'documentary', genres: ['Documentaire']))
    assert_equal '/videos/Documentaires/[*] Exemple (Example) (2023).mkv', result[:target]
  end

  test 'missing reference is distinct from a changed record' do
    result = @service.call(**@arguments.merge(genres: ['Biographie', 'Drame']))
    assert_equal ['Biographie'], result[:missing_genres]
    assert_equal 'missing_genre_reference', result[:status]
    assert_equal false, result[:references_available]
    assert_equal 'Exemple', @record.french_title
  end

  test 'two genres use canonical alphabetical order' do
    result = @service.call(**@arguments.merge(genres: ['Romance', 'Comédie'], known_genres: ['Comédie', 'Romance']))
    assert_equal ['Comédie', 'Romance'], result[:genres]
    assert_includes result[:target], '/Films/Comédie, Romance/'
  end

  test 'a custom root applies to documentary paths' do
    result = CatalogEnrichment::ReviewedClassificationProposal.new(root: '/tmp/vidb-fixtures').call(**@arguments.merge(category: 'documentary', genres: ['Documentaire']))
    assert_equal '/tmp/vidb-fixtures/Documentaires/Exemple (Example) (2023).mkv', result[:target]
  end

  test 'unknown categories are refused' do
    assert_raises(ArgumentError) { @service.call(**@arguments.merge(category: 'series')) }
  end

  test 'documentary is not a film genre directory' do
    assert_raises(ArgumentError) { @service.call(**@arguments.merge(genres: ['Documentaire'])) }
    assert_raises(ArgumentError) { @service.call(**@arguments.merge(category: 'documentary')) }
  end

  test 'invalid genre selections are refused' do
    [[], ['Drame', 'Drame'], ['Drame', 'Comédie', 'Romance'], [' Drame'], [nil], 'Drame'].each do |genres|
      assert_raises(ArgumentError) { @service.call(**@arguments.merge(genres: genres)) }
    end
  end

  test 'dangerous names are refused by the canonical builder' do
    assert_raises(ArgumentError) { @service.call(**@arguments.merge(genres: ['../Drame'])) }
    @record.french_title = '../Exemple'
    assert_raises(ArgumentError) { @service.call(**@arguments) }
  end

  test 'documented reasoning and valid sources are required' do
    assert_raises(ArgumentError) { @service.call(**@arguments.merge(evidence: @arguments[:evidence].merge(reason: ' '))) }
    [[], ['http://example.org'], ['https:///film'], [nil], ['https://user:password@example.org/film']].each do |sources|
      assert_raises(ArgumentError) { @service.call(**@arguments.merge(evidence: @arguments[:evidence].merge(sources: sources))) }
    end
  end
  test 'Biographie is reconciled with the existing Biopic reference' do
    result = @service.call(**@arguments.merge(genres: ['Biographie', 'Drame'], known_genres: ['Biopic', 'Drame']))
    assert_equal ['Biopic', 'Drame'], result[:genres]
    assert_equal [], result[:missing_genres]
    assert_includes result[:target], '/Films/Biographie, Drame/'
  end

  test 'Biopic retains the established directory spelling' do
    result = @service.call(**@arguments.merge(genres: ['Biopic'], known_genres: ['Biopic']))
    assert_equal ['Biopic'], result[:genres]
    assert_includes result[:target], '/Films/Biographie/'
  end

  test 'synonyms cannot create duplicate canonical genres' do
    assert_raises(ArgumentError) do
      @service.call(**@arguments.merge(genres: ['Biographie', 'Biopic'], known_genres: ['Biopic']))
    end
  end
end
