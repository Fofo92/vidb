require 'test_helper'

class RecordRatingUpdateTest < ActiveSupport::TestCase
  setup do
    @user = User.create!(email: 'rating-service@example.com', password: 'password')
    @other_user = User.create!(email: 'rating-service-other@example.com', password: 'password')
    language = LanguageVersion.create!(short_name: 'NOTE', long_name: 'Version notation')
    @series = Record.create!(french_title: 'Série avis', record_kind: 'series', language_version: language)
    @season = @series.children.create!(french_title: 'Saison 1', record_kind: 'season',
                                       language_version: language, rank: 1)
    @episode = @season.children.create!(french_title: 'Épisode avis', record_kind: 'episode',
                                        language_version: language, rank: 1)
  end

  test 'opinions do not alter metadata snapshots timestamps availability or child ratings' do
    snapshot = ReconciliationWorkbench::Snapshot.record(@season.reload)
    version = RecordShowVersion.new(@season, user: @user).call
    RecordRatingUpdate.call(record: @season, user: @user, value: 5)
    assert_equal 5, @season.ratings.find_by!(user: @user).value
    assert_equal snapshot, ReconciliationWorkbench::Snapshot.record(@season.reload)
    assert_not_equal version, RecordShowVersion.new(@season, user: @user).call
    assert_nil @episode.reload.ratings.find_by(user: @user)
    assert_nil @series.reload.ratings.find_by(user: @user)
  end

  test 'the model rejects out of range noninteger and missing notes' do
    [0, 6, 2.5, nil].each do |value|
      rating = RecordRating.new(record: @episode, user: @user, value: value)
      assert_not rating.valid?
      assert rating.errors[:value].any?
    end
  end

  test 'the database rejects a value outside the allowed range' do
    RecordRatingUpdate.call(record: @episode, user: @user, value: 3)
    rating = @episode.ratings.find_by!(user: @user)
    assert_raises(ActiveRecord::StatementInvalid) do
      RecordRating.transaction(requires_new: true) { rating.update_columns(value: 6) }
    end
    assert_equal 3, rating.reload.value
  end

  test 'filters select exact notes or missing opinions and reject invalid values' do
    RecordRatingUpdate.call(record: @season, user: @user, value: 3)
    scope = Record.where(id: [@series.id, @season.id, @episode.id])
    assert_equal [@season.id], RecordIndexFilter.new({ rating: '3' }, scope: scope, user: @user).call.pluck(:id)
    assert_empty RecordIndexFilter.new({ rating: '4' }, scope: scope, user: @user).call
    assert_equal [@series.id, @episode.id].sort,
                 RecordIndexFilter.new({ rating: 'unrated' }, scope: scope, user: @user).call.pluck(:id).sort
    ['0', '6', '2.5', 'unknown'].each do |value|
      assert_raises(ActiveRecord::RecordNotFound) { RecordIndexFilter.new({ rating: value }, scope: scope, user: @user).call }
    end
  end

  test 'another account opinion does not change the current account live version or filters' do
    first = RecordShowVersion.new(@season, user: @user).call
    RecordRatingUpdate.call(record: @season, user: @other_user, value: 5)
    assert_equal first, RecordShowVersion.new(@season, user: @user).call
    scope = Record.where(id: @season.id)
    assert_empty RecordIndexFilter.new({ rating: '5' }, scope: scope, user: @user).call
    assert_equal [@season.id],
                 RecordIndexFilter.new({ rating: 'unrated' }, scope: scope, user: @user).call.pluck(:id)
  end

  test 'destroying a record removes its opinion' do
    RecordRatingUpdate.call(record: @episode, user: @user, value: 1)
    assert_difference('RecordRating.count', -1) { @episode.destroy! }
  end
end
