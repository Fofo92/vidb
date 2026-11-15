# frozen_string_literal: true

require 'test_helper'
require 'uri'

class RecordGenreIconsTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    sign_in User.create!(email: 'genre-icons@example.com', password: 'password')
    @language = LanguageVersion.create!(short_name: 'ICO', long_name: 'Version icônes')
    @comedy = Gender.find_or_create_by!(name: 'Comédie')
    @drama = Gender.find_or_create_by!(name: 'Drame')
    @thriller = Gender.find_or_create_by!(name: 'Thriller')
    @comic = create_film('Icône comique', [@comedy])
    @dramatic = create_film('Icône dramatique', [@drama])
    @mixed = create_film('Icône mixte', [@drama, @comedy])
    @text = create_film('Icône suspense', [@thriller])
  end

  test 'separate masks and the combined theatre symbol keep their accessible genre names' do
    get records_url, params: { q: { french_title_or_original_title_cont: 'Icône' } }
    assert_response :success
    [@comic, @dramatic].each do |record|
      assert_select "[data-record-state-row='#{record.id}'] .record-genre-icons[role='img']" do
        assert_select 'svg.record-genre-mask', count: 1
        assert_select 'svg[aria-hidden=true]', count: 1
      end
    end
    assert_select "[data-record-state-row='#{@mixed.id}'] .record-genre-icons" do |nodes|
      assert_includes nodes.first['aria-label'], 'Comédie'
      assert_includes nodes.first['aria-label'], 'Drame'
      assert_select 'i.fa-masks-theater', count: 1
      assert_select 'svg', count: 0
    end
    assert_select "[data-record-state-row='#{@text.id}'] .record-genre-icons[role=img]" do |nodes|
      assert_equal 'Thriller', nodes.first['title']
      assert_equal 'Thriller', nodes.first['aria-label']
      assert_select 'svg[data-genre-symbol=thriller][aria-hidden=true]', count: 1
    end
  end

  test 'a genre button preserves search sort and year while returning to the first page' do
    get records_url, params: {
      q: { french_title_or_original_title_cont: 'Icône', s: 'id desc' },
      filters: { year: '2020' }, page: '2'
    }
    link = css_select("[data-genre-filter='#{@comedy.id}']").sole
    query = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
    assert_equal @comedy.id.to_s, query.dig('filters', 'gender_id')
    assert_equal '2020', query.dig('filters', 'year')
    assert_equal 'Icône', query.dig('q', 'french_title_or_original_title_cont')
    assert_equal 'id desc', query.dig('q', 's')
    assert_nil query['page']

    get link['href']
    assert_response :success
    assert_select "[data-genre-filter='#{@comedy.id}'][aria-current=true]"
    assert_select "[data-record-state-row='#{@comic.id}']"
    assert_select "[data-record-state-row='#{@dramatic.id}']", count: 0
  end

  test 'all genres clears only the genre criterion' do
    get records_url, params: { filters: { year: '2020', gender_id: @comedy.id } }
    link = css_select('[data-genre-filter=all]').sole
    query = Rack::Utils.parse_nested_query(URI.parse(link['href']).query)
    assert_nil query.dig('filters', 'gender_id')
    assert_equal '2020', query.dig('filters', 'year')

    get link['href']
    assert_select '[data-genre-filter=all][aria-current=true]'
    assert_select "[data-record-state-row='#{@dramatic.id}']"
  end

  private

  def create_film(title, genders)
    Record.create!(french_title: title, record_kind: 'standalone_video', year: 2020,
                   language_version: @language, genders: genders)
  end
end
