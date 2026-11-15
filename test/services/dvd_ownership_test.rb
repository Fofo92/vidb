require 'test_helper'

class DvdOwnershipTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @series = make_record('Code Quantum 1989', 'series')
    @season = make_record('Saison 2', 'season', parent: @series, rank: 2)
    @episode = make_record('Jimmy', 'episode', parent: @season, rank: 8)
    @other_episode = make_record('Autre', 'episode', parent: @season, rank: 9)
    @hd = Medium.find_or_create_by!(short_name: 'HD') { |item| item.long_name = 'Haute définition' }
    @asset = @episode.video_assets.create!(status: 'present', last_known_path: '/videos/Jimmy.mkv', medium: @hd)
  end

  test 'scanning a series adds its DVD support without claiming all catalogue episodes' do
    edition = DvdEdition.create!(ean: '5050582454376', record: @series)
    assert_includes @series.reload.media.pluck(:short_name), 'DVD'
    assert_empty edition.dvd_contents
    assert_empty @episode.reload.media
    assert_empty @other_episode.reload.media
  end

  test 'confirmed contents retain HD files and states while adding physical DVD ownership once' do
    edition = DvdEdition.create!(ean: '5050582454376', record: @series)
    @episode.media << @hd
    before = @episode.reload.attributes.slice('is_available', 'is_recorded', 'is_seen', 'language_version_id')
    assert_no_difference('VideoAsset.count') do
      2.times { DvdOwnership.confirm!(edition: edition, record: @episode) }
    end
    assert_equal [@episode.id], edition.dvd_contents.pluck(:record_id)
    assert_equal %w[DVD HD], @episode.reload.media.pluck(:short_name).sort
    assert_equal @hd.id, @asset.reload.medium_id
    assert_equal before, @episode.attributes.slice(*before.keys)
    summary = VideoAssets::DisplaySummary.new(
      record: @episode, records: [@episode], assets: [@asset], dvd_record_ids: [@episode.id]
    )
    assert_equal 'DVD, HD', summary.summary_supports
    assert_includes summary.supports, 'DVD'
    assert_includes summary.supports, 'HD'
  end

  test 'manual DVD content confirmation also validates the DVD support' do
    edition = DvdEdition.create!(ean: '5050582454376', record: @series)
    edition.dvd_contents.create!(record: @episode)
    assert_includes @episode.reload.media.pluck(:short_name), 'DVD'
    assert_empty @other_episode.reload.media
  end

  test 'physical DVD ownership does not leak from a series into an unconfirmed episode' do
    edition = DvdEdition.create!(ean: '5050582454376', record: @series)
    summary = VideoAssets::DisplaySummary.new(
      record: @episode, records: [@episode], assets: [@asset], dvd_record_ids: [edition.record_id]
    )
    assert_equal 'HD', summary.summary_supports
  end

  test 'copy helper includes an existing DVD holding even when the old media tag is absent' do
    edition = DvdEdition.create!(ean: '5050582454376', record: @series)
    edition.dvd_contents.create!(record: @episode)
    @episode.media.clear
    helper = Class.new { include RecordCopiesHelper }.new
    assert_equal 'DVD, HD', helper.record_copy_summary(@episode).summary_supports
    assert_equal '—', helper.record_copy_summary(@other_episode).summary_supports
  end

  test 'another series cannot be marked as a content of this edition' do
    edition = DvdEdition.create!(ean: '5050582454376', record: @series)
    other = make_record('Code Quantum 2022', 'series')
    assert_no_difference('DvdContent.count') do
      assert_raises(ArgumentError) { DvdOwnership.confirm!(edition: edition, record: other) }
    end
    assert_empty other.reload.media
  end

  test 'scanning a standalone work preserves another existing medium' do
    film = make_record('Film', 'standalone_video')
    film.media << @hd
    DvdEdition.create!(ean: '5050582454376', record: film)
    assert_equal %w[DVD HD], film.reload.media.pluck(:short_name).sort
  end

  private

  def make_record(title, kind, **attributes)
    Record.create!(french_title: title, record_kind: kind, language_version: @language, **attributes)
  end
end
