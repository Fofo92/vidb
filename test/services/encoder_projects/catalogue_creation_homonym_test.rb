require 'test_helper'
require 'minitest/mock'

class EncoderProjects::CatalogueCreationHomonymTest < ActiveSupport::TestCase
  def candidate
    { 'french_title' => 'La Route', 'year' => 2025,
      'source' => { 'url' => 'https://www.themoviedb.org/movie/1541932' } }
  end

  def existing_record(year: 2020, parent: true, kind: 'undetermined')
    record = Struct.new(:id, :year, :parent, :kind).new(6184, year, parent, kind)
    record.define_singleton_method(:has_parent?) { parent }
    record.define_singleton_method(:record_kind_standalone_video?) { kind == 'standalone_video' }
    record
  end

  def lookup(titles, sources = [])
    Record.stub(:where, ->(sql, _value) { sql.include?('year_evidence') ? sources : titles }) do
      EncoderProjects::CatalogueCreation.new(user: nil, url: '').send(:existing, candidate)
    end
  end

  test 'a hierarchical homonym with a different known year does not block creation' do
    assert_nil lookup([existing_record])
  end

  test 'an unknown year still requires review' do
    assert_raises(ArgumentError) { lookup([existing_record(year: nil)]) }
  end

  test 'a hierarchical homonym from the same year still requires review' do
    assert_raises(ArgumentError) { lookup([existing_record(year: 2025)]) }
  end

  test 'a root homonym with a different year still requires review' do
    EncoderProjects::Matcher.stub(:qualified?, true) do
      assert_raises(ArgumentError) { lookup([existing_record(parent: false, kind: 'standalone_video')]) }
    end
  end

  test 'a matching source identity prevents dismissing a hierarchical record' do
    record = existing_record
    assert_raises(ArgumentError) { lookup([record], [record]) }
  end

  test 'an episode is never reused as the selected standalone film' do
    record = existing_record(year: 2025, kind: 'episode')
    EncoderProjects::Matcher.stub(:qualified?, true) do
      assert_raises(ArgumentError) { lookup([record]) }
    end
  end

  test 'a qualified standalone film with the same year is reused' do
    record = existing_record(year: 2025, parent: false, kind: 'standalone_video')
    EncoderProjects::Matcher.stub(:qualified?, true) { assert_same record, lookup([record]) }
  end

  test 'multiple distinct hierarchical homonyms do not hide the concordant standalone film' do
    film = existing_record(year: 2025, parent: false, kind: 'standalone_video')
    film.id = 9000
    EncoderProjects::Matcher.stub(:qualified?, true) { assert_same film, lookup([existing_record, film]) }
  end
end
