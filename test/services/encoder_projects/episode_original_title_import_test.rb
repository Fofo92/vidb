require 'test_helper'

class EncoderProjects::EpisodeOriginalTitleImportTest < ActiveSupport::TestCase
  RecordDouble = Struct.new(:original_title) do
    def update!(original_title:)
      self.original_title = original_title
    end
  end

  test 'fills an absent original title and preserves an existing manual choice' do
    record = RecordDouble.new('')
    importer = EncoderProjects::EpisodeOriginalTitleImport.new({ 'original_title' => 'Departure' }, {})
    importer.call(record)
    assert_equal 'Departure', record.original_title
    record.original_title = 'Manual title'
    importer.call(record)
    assert_equal 'Manual title', record.original_title
  end

  test 'an explicit correction is accepted only against its current signed baseline' do
    record = RecordDouble.new('Departure')
    candidate = { 'original_title' => 'Departure', 'previous_original_title' => 'Departure' }
    importer = EncoderProjects::EpisodeOriginalTitleImport.new(candidate, { 'original_title' => 'The Departure' })
    importer.call(record)
    assert_equal 'The Departure', record.original_title
    record.original_title = 'Concurrent title'
    assert_raises(ArgumentError) { importer.call(record) }
    assert_equal 'Concurrent title', record.original_title
  end

  test 'blank input preserves a proposed original title' do
    record = RecordDouble.new('')
    EncoderProjects::EpisodeOriginalTitleImport.new({ 'original_title' => 'Departure' }, { 'original_title' => '' }).call(record)
    assert_equal 'Departure', record.original_title
  end
end
