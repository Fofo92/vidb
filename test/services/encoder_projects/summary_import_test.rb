require 'test_helper'

class EncoderProjects::SummaryImportTest < ActiveSupport::TestCase
  class RecordDouble
    attr_accessor :abstract, :manual, :source

    def initialize(text, manual: false)
      @abstract = text
      @manual = manual
    end

    def abstract_protected?
      manual
    end

    def update!(abstract:)
      self.abstract = abstract
      self.manual = true
    end

    def save_external_abstract!(text, source:)
      raise 'manual text overwritten' if manual

      self.abstract = text
      self.source = source
    end
  end

  def candidate
    { 'abstract' => 'Synopsis court.', 'previous_abstract' => 'Ancien récit.', 'replace_external_abstract' => true,
      'source' => { 'provider' => 'wikipedia' }, 'abstract_source' => { 'provider' => 'tmdb' } }
  end

  test 'a confirmed external replacement records the synopsis own source' do
    record = RecordDouble.new('Ancien récit.')
    EncoderProjects::SummaryImport.new(candidate: candidate, parameters: {}).call(record, 'Synopsis court.')
    assert_equal 'Synopsis court.', record.abstract
    assert_equal 'tmdb', record.source['provider']
  end

  test 'a manual or concurrently edited summary cannot be replaced automatically' do
    [RecordDouble.new('Ancien récit.', manual: true), RecordDouble.new('Texte plus récent.')].each do |record|
      before = record.abstract
      assert_raises(ArgumentError) do
        EncoderProjects::SummaryImport.new(candidate: candidate, parameters: {}).call(record, 'Synopsis court.')
      end
      assert_equal before, record.abstract
    end
  end

  test 'an explicit edit remains a protected manual summary' do
    record = RecordDouble.new('Ancien récit.')
    service = EncoderProjects::SummaryImport.new(candidate: candidate, parameters: { 'abstract' => 'Mon texte.' })
    service.call(record, 'Mon texte.')
    assert_equal 'Mon texte.', record.abstract
    assert record.manual
  end
end
