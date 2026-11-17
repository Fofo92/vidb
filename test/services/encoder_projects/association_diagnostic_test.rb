require 'test_helper'
require 'minitest/mock'

class EncoderProjects::AssociationDiagnosticTest < ActiveSupport::TestCase
  setup do
    @language = LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
  end

  def record(kind, parent: nil)
    Record.create!(french_title: "Fiche #{kind}", record_kind: kind, parent: parent, language_version: @language)
  end

  def diagnostic(item)
    EncoderProjects::AssociationDiagnostic.call(item)
  end

  test 'qualified standalone videos and episodes have no blocking diagnostic' do
    collection = record('collection')
    series = record('series')
    season = record('season', parent: series)
    [record('standalone_video'), record('standalone_video', parent: collection),
     record('episode', parent: season)].each do |item|
      assert EncoderProjects::Matcher.qualified?(item)
      assert_nil diagnostic(item)
    end
  end

  test 'an unspecified nature points to the proposed record' do
    item = record('undetermined')
    issue = diagnostic(item)
    assert_equal item, issue.record
    assert_equal :edit, issue.action
    assert_includes issue.message, 'Nature non renseignée'
  end

  test 'an unspecified parent nature points to that parent rather than the child' do
    parent = record('undetermined')
    item = record('standalone_video', parent: parent)
    issue = diagnostic(item)
    assert_equal parent, issue.record
    assert_equal :edit, issue.action
    assert_includes issue.message, 'fiche parent'
  end

  test 'a container is consulted without suggesting that it should become a film' do
    series = record('series')
    issue = diagnostic(series)
    assert_equal :show, issue.action
    assert_includes issue.message, 'Série'
    record('season', parent: series)
    issue = diagnostic(series.reload)
    assert_equal :show, issue.action
    assert_includes issue.message, 'contient des enfants'
  end

  test 'a legacy film under a series identifies its incompatible parent and the placement action' do
    parent = record('collection')
    item = record('standalone_video', parent: parent)
    parent.update_columns(record_kind: 'series')
    issue = diagnostic(item.reload)
    assert_equal item, issue.record
    assert_equal :placement, issue.action
    assert_includes issue.message, "parent n° #{parent.id}"
    assert_includes issue.message, 'Série'
  end

  test 'an episode directly under a series needs a season even when its episode rank is correct' do
    item = record('episode', parent: record('series'))
    item.update!(rank: 6)
    issue = diagnostic(item)
    assert_equal item, issue.record
    assert_equal :placement, issue.action
    assert_includes issue.message, 'rattaché à une saison'
    assert_equal 6, item.reload.rank
  end

  test 'a season without a series is the target of an episode diagnostic' do
    parent = record('undetermined')
    season = record('season', parent: parent)
    item = record('episode', parent: season)
    issue = diagnostic(item)
    assert_equal season, issue.record
    assert_equal :placement, issue.action
    assert_includes issue.message, 'nature « Série »'
  end

  test 'missing records and broken parent references are explained without raising' do
    assert_nil diagnostic(nil).record
    assert_includes diagnostic(nil).message, 'n’existe plus'
    item = record('standalone_video')
    item.stub(:has_parent?, true) do
      item.stub(:parent, nil) do
        assert_equal :placement, diagnostic(item).action
        assert_includes diagnostic(item).message, 'introuvable'
      end
    end
  end

  test 'an orphan episode points to its own placement' do
    item = record('standalone_video')
    item.update_columns(record_kind: 'episode')
    issue = diagnostic(item.reload)
    assert_equal :placement, issue.action
    assert_includes issue.message, 'aucun parent'
  end
end
