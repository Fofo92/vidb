require 'test_helper'

class EncoderProjects::CatalogueSummaryImportTest < ActiveSupport::TestCase
  setup do
    language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @record = Record.create!(french_title: 'Film test', record_kind: 'standalone_video', language_version: language)
    @candidate = { 'abstract' => 'Synopsis court.', 'source' => { 'provider' => 'wikipedia' },
                   'abstract_source' => { 'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/movie/7' } }
  end

  test 'a confirmed external synopsis replaces external text with its own provenance' do
    @record.save_external_abstract!('Ancien récit.', source: { 'provider' => 'wikipedia' })
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      EncoderProjects::CatalogueSummaryImport.call(@record, @candidate)
    end
    assert_equal 'Synopsis court.', @record.reload.abstract
    assert_equal 'external', @record.abstract_provenance['kind']
    assert_equal 'tmdb', @record.abstract_provenance.dig('source', 'provider')
  end

  test 'manual summaries are preserved and a preferred source is not downgraded' do
    @record.update!(abstract: 'Mon résumé.')
    before = @record.attributes
    EncoderProjects::CatalogueSummaryImport.call(@record, @candidate)
    assert_equal before, @record.reload.attributes
    external = Record.create!(french_title: 'Autre film', record_kind: 'standalone_video',
                              language_version: @record.language_version)
    external.save_external_abstract!('Synopsis TMDB.', source: { 'provider' => 'tmdb' })
    candidate = @candidate.merge('abstract_source' => { 'provider' => 'wikipedia' })
    EncoderProjects::CatalogueSummaryImport.call(external, candidate)
    assert_equal 'Synopsis TMDB.', external.reload.abstract
  end
end
