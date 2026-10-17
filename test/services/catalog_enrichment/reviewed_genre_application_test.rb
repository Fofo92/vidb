# frozen_string_literal: true

require 'test_helper'

class ReviewedGenreApplicationTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'GP_TEST', long_name: 'Genre protection test')
    @first = Gender.create!(name: 'GP_TEST_A')
    @second = Gender.create!(name: 'GP_TEST_B')
    @record = Record.create!(french_title: 'Genre protection test', year: 2000, language_version: @language,
                             record_kind: 'standalone_video', genders: [@first])
    # Deliberate fixture for a legacy record immediately after the additive migration.
    @record.update_columns(genre_provenance: {})
    @expected = { genres: [@first.name], provenance: {} }
    @evidence = { reason: 'Documented classification.', sources: ['https://example.org/film'] }
    @service = CatalogEnrichment::ReviewedGenreApplication.new
  end

  def apply(genres: [@second.name], operation_id: 'genre-protection-test')
    @service.call(record: @record, genres: genres, expected: @expected,
                  evidence: @evidence, operation_id: operation_id)
  end

  test 'documented classification stores previous genres and evidence atomically' do
    assert_equal 'applied', apply[:status]
    assert_equal [@second.name], @record.reload.genders.map(&:name)
    assert_equal [@first.name], @record.genre_provenance['previous_genres']
    assert_equal @evidence.deep_stringify_keys, @record.genre_provenance['evidence']
  end

  test 'replay is idempotent and does not rewrite the receipt' do
    apply
    receipt = @record.reload.genre_provenance.deep_dup
    assert_equal 'already_applied', apply[:status]
    assert_equal receipt, @record.reload.genre_provenance
  end

  test 'operation identity cannot be reused for another selection' do
    apply
    assert_raises(ArgumentError) { apply(genres: [@first.name]) }
  end

  test 'another external operation cannot replace a qualified selection' do
    apply
    assert_equal 'protected', apply(genres: [@first.name], operation_id: 'another')[:status]
    assert_equal [@second.name], @record.reload.genders.map(&:name)
  end

  test 'manual replacement is protected and archives the reviewed receipt' do
    apply
    @record.genders = [@first]
    receipt = @record.reload.genre_provenance
    assert_equal 'manual_or_untracked', receipt['origin']
    assert receipt['protected']
    assert receipt['history'].any? { |row| row['operation_id'] == 'genre-protection-test' }
    assert_equal 'protected', apply[:status]
  end

  test 'manual clear is protected even if the same selection is later restored' do
    apply
    @record.genders.clear
    assert_equal [], @record.reload.genre_provenance['genres']
    @record.genders = [@second]
    assert_equal 'protected', apply[:status]
    assert_equal 'manual_or_untracked', @record.reload.genre_provenance['origin']
  end

  test 'manual bulk deletion is protected' do
    @record.genders.delete_all
    assert_equal [], @record.reload.genre_provenance['genres']
    assert_equal 'protected', apply[:status]
  end

  test 'pending form attributes survive association callbacks' do
    @record.assign_attributes(french_title: 'Corrected title')
    @record.genders = [@second]
    @record.save!
    assert_equal 'Corrected title', @record.reload.french_title
    assert_equal 'manual_or_untracked', @record.genre_provenance['origin']
  end

  test 'a changed legacy snapshot is refused without writes' do
    @record.with_reviewed_genre_assignment { @record.genders = [@second] }
    assert_equal 'changed_since_proposal', apply[:status]
    assert_equal({}, @record.reload.genre_provenance)
  end

  test 'a transaction rollback restores joins and provenance together' do
    @record.define_singleton_method(:update!) { |**_attributes| raise ActiveRecord::RecordInvalid, self }
    assert_raises(ActiveRecord::RecordInvalid) { apply }
    assert_equal [@first.name], @record.reload.genders.map(&:name)
    assert_equal({}, @record.genre_provenance)
  end

  test 'missing genre references cannot partially change the record' do
    assert_raises(ArgumentError) { apply(genres: ['GP_TEST_MISSING']) }
    assert_equal [@first.name], @record.reload.genders.map(&:name)
    assert_equal({}, @record.genre_provenance)
  end

  test 'a form transaction rollback also rolls back the manual protection' do
    Record.transaction do
      @record.genders = [@second]
      raise ActiveRecord::Rollback
    end
    assert_equal [@first.name], @record.reload.genders.map(&:name)
    assert_equal({}, @record.genre_provenance)
  end

  test 'new records with a manually chosen genre are protected' do
    record = Record.create!(french_title: 'New manual record', language_version: @language, genders: [@first])
    assert_equal [@first.name], record.reload.genre_provenance['genres']
    assert record.genre_provenance['protected']
  end
  test 'normal form updates protect gender ids together with other fields' do
    @record.update!(gender_ids: [@second.id], french_title: 'Form correction')
    assert_equal 'Form correction', @record.reload.french_title
    assert_equal [@second.name], @record.genre_provenance['genres']
    assert_equal 'protected', apply[:status]
  end

  test 'individual addition and removal both protect the selection' do
    @record.genders << @second
    assert_equal [@first.name, @second.name], @record.reload.genre_provenance['genres']
    @record.genders.delete(@first)
    assert_equal [@second.name], @record.reload.genre_provenance['genres']
    assert_equal 'protected', apply[:status]
  end
end
