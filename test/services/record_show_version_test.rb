require 'test_helper'
require 'base64'

class RecordShowVersionTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.create!(short_name: 'LIVE', long_name: 'Version actualisation')
    @series = Record.create!(french_title: 'Série actualisée', record_kind: 'series', language_version: @language)
    @season = @series.children.create!(french_title: 'Saison 01', rank: 1, record_kind: 'season', language_version: @language)
    @episode = @season.children.create!(french_title: 'Épisode', rank: 1, record_kind: 'episode', language_version: @language)
  end

  def version(record = @season)
    RecordShowVersion.new(record.reload).call
  end

  test 'the version is stable and computes no record changes' do
    before = @season.attributes.deep_dup
    first = version
    assert_match(/\A[a-f0-9]{64}\z/, first)
    assert_equal first, version
    assert_equal before, @season.reload.attributes
  end

  test 'direct editorial changes are detected even without touching timestamps' do
    before = version
    @episode.update_columns(french_title: 'Titre corrigé')
    assert_not_equal before, version
  end

  test 'an ancestor and insertion or removal of a child invalidate the version' do
    before = version
    @series.update!(original_title: 'New series title')
    assert_not_equal before, version
    child = @season.children.create!(french_title: 'Nouvel épisode', record_kind: 'episode', language_version: @language)
    middle = version
    child.destroy!
    assert_not_equal middle, version
  end

  test 'countries and edited reference labels invalidate the version without touching the record' do
    country = Country.create!(short_name: 'LV', long_name: 'Pays actualisation')
    before = version
    @series.countries << country
    assert_not_equal before, version
    before = version
    country.update!(long_name: 'Pays corrigé')
    assert_not_equal before, version
  end

  test 'genre and medium assignments are included' do
    genre = Gender.create!(name: 'Genre actualisation')
    medium = Medium.create!(short_name: 'LV', long_name: 'Support actualisation')
    before = version
    @episode.genders << genre
    assert_not_equal before, version
    before = version
    @episode.media << medium
    assert_not_equal before, version
  end

  test 'copy metadata and status changes invalidate the version without saving its record' do
    before = version
    asset = @episode.video_assets.create!(last_known_path: '/videos/live.mkv', status: 'present', duration_minutes: 42)
    assert_not_equal before, version
    before = version
    asset.update_columns(duration_minutes: 44)
    assert_not_equal before, version
    before = version
    asset.update!(status: 'missing')
    assert_not_equal before, version
  end

  test 'inherited poster attachments invalidate the version' do
    before = version
    png = Base64.decode64('iVBORw0KGgoAAAANSUhEUgAAAAEAAAABCAQAAAC1HAwCAAAAC0lEQVR42mP8/x8AAwMCAO+/2k0AAAAASUVORK5CYII=')
    poster = RecordPoster.create!(record: @series, source: { 'kind' => 'manual' })
    poster.image.attach(io: StringIO.new(png), filename: 'live.png', content_type: 'image/png')
    assert_not_equal before, version
    before = version
    poster.image.detach
    assert_not_equal before, version
  end
end
