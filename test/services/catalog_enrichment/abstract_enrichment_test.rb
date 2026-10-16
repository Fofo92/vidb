# frozen_string_literal: true

require 'test_helper'

class AbstractEnrichmentTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.create!(short_name: 'ABST', long_name: 'Test résumé')
    @record = Record.create!(french_title: 'Film test résumé', language_version: language,
                             record_kind: 'standalone_video')
    @source = { provider: 'tmdb', external_id: 42 }
  end

  test 'preview of a missing summary does not write provenance or text' do
    before = @record.attributes
    result = enrich
    assert_equal 'candidate', result[:status]
    assert_equal false, result[:applied]
    assert_equal before, @record.reload.attributes
  end

  test 'a missing summary can be filled and refreshed by the same identified source' do
    assert_equal 'applied', enrich(apply: true)[:status]
    assert_equal 'Résumé externe', @record.reload.abstract
    assert_equal 'external', @record.abstract_provenance['kind']
    assert_equal 'tmdb', @record.abstract_provenance.dig('source', 'provider')
    assert_equal 'applied', enrich(text: 'Résumé actualisé', apply: true)[:status]
    assert_equal 'Résumé actualisé', @record.reload.abstract
  end

  test 'same text is idempotent without restamping provenance' do
    enrich(apply: true)
    before = @record.reload.attributes
    assert_equal 'unchanged', enrich(apply: true)[:status]
    assert_equal before, @record.reload.attributes
  end

  test 'an editorial correction is protected from a later source refresh' do
    enrich(apply: true)
    @record.update!(abstract: 'Ma rédaction corrigée')
    result = enrich(apply: true)
    assert_equal 'protected', result[:status]
    assert_equal true, result[:editorial_validation_required]
    assert_equal 'Ma rédaction corrigée', @record.reload.abstract
    assert_equal 'manual', @record.abstract_provenance['kind']
  end

  test 'a deliberate manual deletion stays protected even though the field is blank' do
    enrich(apply: true)
    @record.update!(abstract: '')
    assert @record.abstract_protected?
    assert_equal 'protected', enrich(apply: true)[:status]
    assert_equal '', @record.reload.abstract
  end

  test 'saving an untouched empty textarea does not prevent enrichment' do
    @record.update!(abstract: '')
    assert_equal({}, @record.abstract_provenance)
    assert_equal 'applied', enrich(apply: true)[:status]
  end

  test 'a legacy nonempty summary is preserved without inventing its provenance' do
    @record.update_columns(abstract: 'Résumé historique', abstract_provenance: {})
    before = @record.reload.attributes
    assert_equal 'protected', enrich(apply: true)[:status]
    assert_equal before, @record.reload.attributes
  end

  test 'a new summary typed manually is protected' do
    @record.update!(abstract: 'Texte personnel')
    assert_equal 'manual', @record.abstract_provenance['kind']
    assert_equal 'protected', enrich(apply: true)[:status]
    assert_equal 'Texte personnel', @record.reload.abstract
  end

  test 'a blank source response never erases existing text' do
    enrich(apply: true)
    [nil, '', '  '].each do |text|
      assert_equal 'no_candidate', enrich(text: text, apply: true)[:status]
    end
    assert_equal 'Résumé externe', @record.reload.abstract
  end

  test 'ambiguous identity and missing source evidence prevent automatic application' do
    assert_equal 'needs_review', enrich(identity_confirmed: false, apply: true)[:status]
    assert_equal 'needs_review', enrich(source: {}, apply: true)[:status]
    assert_nil @record.reload.abstract
  end

  test 'another provider or work cannot replace the last imported summary' do
    enrich(apply: true)
    [{ provider: 'other', external_id: 42 }, { provider: 'tmdb', external_id: 43 }].each do |source|
      assert_equal 'source_changed', enrich(text: 'Autre texte', source: source, apply: true)[:status]
    end
    assert_equal 'Résumé externe', @record.reload.abstract
  end

  test 'a stale instance reloads the manual correction before deciding to apply' do
    enrich(apply: true)
    stale = Record.find(@record.id)
    @record.update!(abstract: 'Correction postérieure à la prévisualisation')
    result = CatalogEnrichment::AbstractEnrichment.new(record: stale, text: 'Nouvelle source', source: @source,
                                                       identity_confirmed: true).call(apply: true)
    assert_equal 'protected', result[:status]
    assert_equal 'Correction postérieure à la prévisualisation', @record.reload.abstract
  end

  test 'a bypassed callback cannot authorize overwriting text with a mismatched provenance digest' do
    enrich(apply: true)
    @record.update_columns(abstract: 'Correction hors formulaire')
    assert_equal 'protected', enrich(apply: true)[:status]
    assert_equal 'Correction hors formulaire', @record.reload.abstract
  end

  test 'updating another attribute does not change summary provenance' do
    enrich(apply: true)
    before = @record.reload.abstract_provenance
    @record.update!(french_title: 'Autre titre')
    assert_equal before, @record.reload.abstract_provenance
  end

  test 'accepting a replacement by editing the record remains protected afterwards' do
    @record.update!(abstract: 'Résumé personnel')
    @record.update!(abstract: 'Texte externe accepté après lecture')
    assert_equal 'protected', enrich(apply: true)[:status]
    assert_equal 'Texte externe accepté après lecture', @record.reload.abstract
  end

  test 'an invalid external update rolls back and does not leak its source context' do
    validation = -> { errors.add(:abstract, 'Test invalid text') if abstract == 'Résumé externe' }
    Record.validate validation
    assert_raises(ActiveRecord::RecordInvalid) { enrich(apply: true) }
    @record.reload
    assert_nil @record.abstract
    assert_equal({}, @record.abstract_provenance)
    @record.update!(abstract: 'Texte manuel après échec')
    assert_equal 'manual', @record.reload.abstract_provenance['kind']
  ensure
    Record.skip_callback(:validate, :before, validation) if validation
  end

  test 'unexpected structured summaries are rejected before writing' do
    assert_raises(ArgumentError) { enrich(text: { broken: 'response' }, apply: true) }
    assert_nil @record.reload.abstract
  end

  private

  def enrich(text: 'Résumé externe', source: @source, identity_confirmed: true, apply: false)
    CatalogEnrichment::AbstractEnrichment.new(record: @record, text: text, source: source,
                                              identity_confirmed: identity_confirmed).call(apply: apply)
  end
end
