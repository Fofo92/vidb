# frozen_string_literal: true

require 'test_helper'

class RecordFilmCollectionTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'VF', long_name: 'Version française')
    @collection = create_record('Collection', record_kind: 'collection')
  end

  test 'a collection accepts ordered films and pending records but no series hierarchy' do
    assert_equal :consistent, @collection.hierarchy_placement_status
    assert_equal %w[standalone_video], @collection.allowed_record_kinds_for_child_qualification
    %w[series season episode collection].each do |kind|
      record = Record.new(french_title: 'Contenu', language_version: @language, record_kind: kind, parent: @collection)
      assert_not record.valid?
      assert record.errors[:parent_id].any?
    end
    film = create_record('Film', parent: @collection, record_kind: 'standalone_video', rank: 2)
    pending = create_record('À qualifier', parent: @collection, rank: 1)
    assert_equal [pending.id, film.id], @collection.children.order(:rank).pluck(:id)
    assert_equal :consistent, film.hierarchy_placement_status
  end

  test 'collection states and years summarize films rather than scalar flags' do
    first = create_record('Premier', parent: @collection, record_kind: 'standalone_video', rank: 1,
                                     year: 1962, is_seen: true)
    second = create_record('Deuxième', parent: @collection, record_kind: 'standalone_video', rank: 2, year: 1963)
    @collection.update!(is_seen: true, year: 2000)
    assert_equal '1962-1963', @collection.display_range_of_years
    assert_equal [first.id, second.id].sort, @collection.state_leaves.map(&:id).sort
    assert_equal({ yes: 1, no: 1, unknown: 0, total: 2 }, @collection.state_counts[:is_seen])
    assert_nil @collection.seen_state_confirmed_at
  end

  test 'collection references are derived from films without being inherited by them' do
    country = Country.create!(short_name: 'GB', long_name: 'Royaume-Uni')
    stale = Country.create!(short_name: 'FR', long_name: 'France')
    genre = Gender.create!(name: 'Action')
    @collection.countries << stale
    @collection.genders << Gender.create!(name: 'Aventure')
    film = create_record('Film', parent: @collection, record_kind: 'standalone_video')
    film.countries << country
    film.genders << genre
    blank = create_record('Film à compléter', parent: @collection, record_kind: 'standalone_video')
    values = RecordMetadataValues.new(record: @collection)
    assert_equal [country.id], values.countries.map(&:id)
    assert_equal [genre.id], values.genders.map(&:id)
    assert_empty blank.effective_countries
    assert_empty blank.effective_genders
  end

  test 'audit groups collections without repeating film deficiencies on the container' do
    create_record('Film', parent: @collection, record_kind: 'standalone_video')
    audit = RecordMetadataAudit.new.call
    assert_equal 1, audit[:groups][:collections][:total]
    refute(audit[:records].any? { |row| row[:id] == @collection.id })
    assert_equal 1, audit[:missing][:year]
    assert_equal 1, audit[:missing][:abstract]
  end

  test 'an empty collection has no video leaf and is flagged for review' do
    assert_empty @collection.state_leaves
    assert_equal 0, @collection.state_counts[:is_seen][:total]
    row = RecordMetadataAudit.new.call[:records].find { |item| item[:id] == @collection.id }
    assert_equal ['Ensemble sans enfant'], row[:review]
    assert_empty row[:missing]
  end

  test 'collection copy summaries aggregate its films' do
    medium = Medium.create!(short_name: 'HD', long_name: 'Disque dur')
    film = create_record('Film', parent: @collection, record_kind: 'standalone_video', year: 1962)
    asset = VideoAsset.create!(record: film, last_known_path: '/videos/collection-film.mkv', medium: medium,
                               language_version: @language, duration_minutes: 110)
    summary = VideoAssets::DisplaySummary.new(record: @collection, records: [@collection, film], assets: [asset])
    assert_equal 'HD', summary.summary_supports
    assert_equal 'VF', summary.summary_languages
    assert_equal '01:50', summary.summary_duration
    assert_equal 1, @collection.state_counts[:is_available][:yes]
  end

  private

  def create_record(title, attributes = {})
    Record.create!({ french_title: title, language_version: @language }.merge(attributes))
  end
end
