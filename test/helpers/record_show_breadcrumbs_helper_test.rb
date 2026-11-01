require 'test_helper'

class RecordShowBreadcrumbsHelperTest < ActiveSupport::TestCase
  include RecordsHelper
  include RecordShowBreadcrumbsHelper

  Node = Struct.new(:record_kind, :french_title, :original_title, :rank, :ancestors) do
    def complete_title
      original_title.present? ? "#{french_title} (#{original_title})" : french_title
    end

    def has_parent?
      ancestors.any?
    end
  end

  test 'standalone films show the kind genres and bilingual title' do
    item = Node.new('standalone_video', 'Titre français', 'Original', nil, [])
    labels = record_show_breadcrumbs(item, genres: 'Espionnage, Policier').pluck(:label)
    assert_equal ['Vidéo autonome', 'Espionnage, Policier', 'Titre français (Original)'], labels
  end

  test 'collection films retain the collection and rank without repeating the entire path in the title' do
    group = Node.new('collection', 'James Bond 007', '', nil, [])
    film = Node.new('standalone_video', 'Contre Docteur No', 'Dr. No', 1, [group])
    labels = record_show_breadcrumbs(film, genres: 'Espionnage, Policier').pluck(:label)
    assert_equal ['Vidéo autonome', 'Espionnage, Policier', 'Collection James Bond 007',
                  '1 - Contre Docteur No (Dr. No)'], labels
  end

  test 'series episodes show series season and ranked episode' do
    series = Node.new('series', 'Friends', 'Friends', nil, [])
    season = Node.new('season', 'Saison 01', '', 1, [series])
    episode = Node.new('episode', 'Celui qui déménage', 'The One Where Monica Gets A New Roommate', 1, [series, season])
    path = record_show_breadcrumbs(episode, genres: 'Comédie')
    assert_equal ['Friends (Friends)', 'Saison 1',
                  '1 - Celui qui déménage (The One Where Monica Gets A New Roommate)'], path.pluck(:label)
    assert_same series, path.first[:record]
    assert_same episode, path.last[:record]
  end

  test 'an unspecified kind and a missing rank do not invent a category or number' do
    item = Node.new('undetermined', 'Œuvre', '', nil, [])
    assert_equal ['Œuvre'], record_show_breadcrumbs(item).pluck(:label)
  end
end
