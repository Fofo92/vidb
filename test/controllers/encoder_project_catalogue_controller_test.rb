require 'test_helper'
require 'minitest/mock'

class EncoderProjectCatalogueControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: 'catalogue-encoder@example.com', password: 'password')
    LanguageVersion.find_or_create_by!(short_name: 'IND') { |item| item.long_name = 'Indéterminée' }
    @genre = Gender.find_or_create_by!(name: 'Drame')
    @country = Country.find_by(long_name: 'France') || Country.create!(short_name: 'FR', long_name: 'France')
    @project = { 'project_id' => SecureRandom.uuid, 'project_path' => '/videos/Adieu Philippine.json',
                 'output_path' => '/videos/Adieu Philippine.mkv', 'source_paths' => ['/commun/to_be_cut/capture.m2t'] }
    @candidate = { 'french_title' => 'Adieu Philippine', 'original_title' => '', 'year' => 1962,
                   'genres_text' => 'Drame', 'countries_text' => 'France', 'abstract' => 'Résumé de test.',
                   'record_kind' => 'standalone_video', 'source' => {
                     'provider' => 'wikipedia', 'url' => 'https://fr.wikipedia.org/wiki/Adieu_Philippine' } }
    @request_token = EncoderProjects::CatalogueScope.issue(user: @user, project: @project)
    @proposal = EncoderProjects::CatalogueScope.issue(user: @user, project: @project, candidate: @candidate)
    sign_in @user
  end

  def confirm(proposal = @proposal, genders: [@genre.id])
    post encoder_projects_catalogue_path, params: { request_token: @request_token, proposal_token: proposal,
                                                   gender_ids: genders, country_ids: [@country.id] }
  end

  test 'search displays documented candidates without creating a record or a file association' do
    candidate = @candidate
    catalogue = Object.new
    catalogue.define_singleton_method(:call) { |_query| [candidate] }
    catalogue.define_singleton_method(:warnings) { [] }
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      EncoderProjects::FilmCatalogue.stub(:new, -> { catalogue }) do
        get encoder_projects_catalogue_path, params: { request_token: @request_token }
      end
    end
    assert_response :success
    assert_select 'h2', /Adieu Philippine.*1962/
    assert_select 'input[name="proposal_token"]', count: 1
  end

  test 'confirmation creates a complete film and binds it before encoding without claiming a physical copy' do
    assert_difference 'Record.count', 1 do
      assert_no_difference 'VideoAsset.count' do
        confirm
      end
    end
    record = Record.find_by!(french_title: 'Adieu Philippine')
    assert_redirected_to record_path(record)
    assert_equal 'standalone_video', record.record_kind
    assert_equal 1962, record.year
    assert_equal 'first_release', record.year_basis
    assert_equal [@genre.id], record.gender_ids
    assert_equal [@country.id], record.country_ids
    assert_equal 'Résumé de test.', record.abstract
    assert_equal 'external', record.abstract_provenance['kind']
    assert_equal 'IND', record.language_version.short_name
    assert_equal false, record.is_recorded
    assert_equal false, record.is_available
    assert_equal false, record.is_seen
    assert_nil record.length_in_mn
    assert_empty record.media
    assert_equal record.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
    assert_no_difference 'Record.count' do
      confirm
    end
  end

  test 'a confirmed SensCritique film uses the existing creation and binding transaction' do
    candidate = @candidate.merge('french_title' => 'Impossible', 'year' => 2026, 'source' => {
      'provider' => 'senscritique', 'url' => 'https://www.senscritique.com/film/impossible/139932052'
    })
    proposal = EncoderProjects::CatalogueScope.issue(user: @user, project: @project, candidate: candidate)
    assert_difference 'Record.count', 1 do
      assert_no_difference 'VideoAsset.count' do
        confirm(proposal)
      end
    end
    record = Record.find_by!(french_title: 'Impossible')
    assert_equal 'senscritique', record.year_evidence['provider']
    assert_equal false, record.is_recorded
    assert_equal false, record.is_available
    assert_equal false, record.is_seen
    assert_equal record.id, EncoderProjects::Binding.current(@project['project_id'])['record_id']
  end

  test 'external completion fills the associated film without replacing its reviewed metadata or binding' do
    confirm
    original_binding = EncoderProjects::Binding.current(@project.fetch('project_id'))
    record = Record.find(original_binding.fetch('record_id'))
    record.update!(genre_provenance: {})
    record.with_reviewed_genre_assignment { record.genders = [] }
    candidate = @candidate.merge('abstract' => 'Autre résumé proposé par la source.')

    result = EncoderProjects::Identification.new(user: @user, url: 'https://vidb.test').call(@project)
    uri = URI.parse(result.fetch(:review_url))
    request_token = Rack::Utils.parse_query(uri.query).fetch('request_token')
    scope = EncoderProjects::CatalogueScope.read(request_token, user: @user)
    assert_equal record.id, scope.dig('project', 'completion_record_id')
    proposal_token = EncoderProjects::CatalogueScope.issue(user: @user, project: scope.fetch('project'),
                                                           candidate: candidate)

    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      post encoder_projects_catalogue_path, params: { request_token: request_token, proposal_token: proposal_token,
                                                     gender_ids: [@genre.id], encoder_window: '1' }
    end

    assert_redirected_to record_path(record, encoder_prepared: 1)
    assert_equal [@genre.id], record.reload.gender_ids
    assert_equal 'Résumé de test.', record.abstract
    assert_equal [@country.id], record.country_ids
    assert_equal original_binding, EncoderProjects::Binding.current(@project.fetch('project_id'))
  end

  test 'an already qualified concordant record is reused without rewriting its metadata' do
    record = Record.create!(french_title: 'Adieu Philippine', year: 1962, record_kind: 'standalone_video',
                             language_version: LanguageVersion.find_by!(short_name: 'IND'), abstract: 'Texte manuel')
    before = record.attributes
    assert_no_difference 'Record.count' do
      confirm
    end
    assert_redirected_to record_path(record)
    assert_equal before, record.reload.attributes
  end

  test 'an existing undetermined homonym requires consolidation instead of a duplicate' do
    Record.create!(french_title: 'Adieu Philippine', record_kind: 'undetermined',
                   language_version: LanguageVersion.find_by!(short_name: 'IND'))
    assert_no_difference 'Record.count' do
      confirm
    end
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
    assert_redirected_to encoder_projects_catalogue_path(request_token: @request_token)
  end

  test 'a hierarchical homonym from another year does not prevent creating a distinct film' do
    language = LanguageVersion.find_by!(short_name: 'IND')
    series = Record.create!(french_title: 'Mystery Road', record_kind: 'undetermined', language_version: language)
    season = Record.create!(french_title: 'Saison 2', parent: series, record_kind: 'undetermined', language_version: language)
    homonym = Record.create!(french_title: 'La route', original_title: 'The Road', year: 2020,
                            parent: season, record_kind: 'undetermined', language_version: language)
    previous = homonym.attributes
    candidate = @candidate.merge('french_title' => 'La Route', 'year' => 2025, 'source' => {
      'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/movie/1541932'
    })
    proposal = EncoderProjects::CatalogueScope.issue(user: @user, project: @project, candidate: candidate)
    assert_difference('Record.count', 1) { assert_no_difference('VideoAsset.count') { confirm(proposal) } }
    record = Record.find(EncoderProjects::Binding.current(@project['project_id']).fetch('record_id'))
    assert_redirected_to record_path(record)
    assert_equal ['standalone_video', 2025, nil], [record.record_kind, record.year, record.parent_id]
    assert_equal previous, homonym.reload.attributes
    assert_no_difference('Record.count') { confirm(proposal) }
  end

  test 'confirming an existing film queues its poster without rewriting the record or fetching an image' do
    record = Record.create!(french_title: 'Adieu Philippine', year: 1962, record_kind: 'standalone_video',
                            language_version: LanguageVersion.find_by!(short_name: 'IND'), abstract: 'Résumé manuel')
    before = record.attributes
    candidate = @candidate.merge('poster_path' => '/poster.jpg', 'source' => {
      'provider' => 'tmdb', 'tmdb_movie_id' => 7, 'url' => 'https://www.themoviedb.org/movie/7'
    })
    proposal = EncoderProjects::CatalogueScope.issue(user: @user, project: @project, candidate: candidate)
    RecordPosters::Fetch.stub(:new, -> { raise 'Unexpected download during confirmation' }) do
      assert_difference('RecordPoster.count', 1) do
        assert_no_difference(['Record.count', 'VideoAsset.count']) { confirm(proposal) }
      end
    end
    assert_redirected_to record_path(record)
    assert_equal before, record.reload.attributes
    assert_equal 7, record.record_poster.source.dig('encoder_pending', 'tmdb_movie_id')
    assert_not record.record_poster.image.attached?
  end

  test 'a tampered proposal is rejected before creation' do
    assert_no_difference 'Record.count' do
      confirm("#{@proposal}invalid")
    end
    assert_response :unprocessable_content
  end

  test 'a release year disagreement does not create a duplicate homonym' do
    Record.create!(french_title: 'Adieu Philippine', year: 1963, record_kind: 'standalone_video',
                   language_version: LanguageVersion.find_by!(short_name: 'IND'))
    assert_no_difference 'Record.count' do
      confirm
    end
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
  end

  test 'a request without a documented candidate cannot create a record' do
    assert_no_difference 'Record.count' do
      confirm(@request_token)
    end
    assert_redirected_to encoder_projects_catalogue_path(request_token: @request_token)
  end

  test 'more than two main genres prevents creation' do
    other = %w[Comédie Policier].map { |name| Gender.find_or_create_by!(name: name).id }
    assert_no_difference 'Record.count' do
      confirm(genders: [@genre.id] + other)
    end
    assert_nil EncoderProjects::Binding.current(@project['project_id'])
  end

  test 'a signed proposal belongs to the requesting vidb account' do
    other = User.create!(email: 'other-catalogue@example.com', password: 'password')
    sign_out @user
    sign_in other
    assert_no_difference 'Record.count' do
      confirm
    end
    assert_response :unprocessable_content
  end

  test 'compact candidate forms retain selected references and show an optional TMDB poster' do
    candidate = @candidate.merge('poster_path' => '/poster.jpg', 'additional_sources' => [
      { 'provider' => 'tmdb', 'url' => 'https://www.themoviedb.org/movie/7' }
    ])
    display_candidates([candidate])
    assert_response :success
    assert_select 'select[name="gender_ids[]"][multiple][size="3"][data-controller="encoder-choices"]', count: 1
    assert_select 'select[name="country_ids[]"][multiple][size="3"][data-controller="encoder-choices"]', count: 1
    assert_select 'select[name="gender_ids[]"] option[selected][value=?]', @genre.id.to_s, count: 1
    assert_select 'select[name="country_ids[]"] option[selected][value=?]', @country.id.to_s, count: 1
    assert_select 'img[src="https://image.tmdb.org/t/p/w185/poster.jpg"][loading="lazy"]', count: 1
    assert_select 'a[href="https://www.themoviedb.org/movie/7"]', count: 1
    assert_select 'input[name="proposal_token"]', count: 1
  end

  test 'multiple cards have unique field IDs and no blank poster placeholder' do
    display_candidates([@candidate, @candidate.merge('french_title' => 'Autre film')])
    assert_response :success
    assert_select 'select[id="film-genres-0"]', count: 1
    assert_select 'select[id="film-genres-1"]', count: 1
    assert_select 'label[for="film-genres-1"]', count: 1
    assert_select 'figure.encoder-proposal-artwork', count: 0
  end

  def display_candidates(candidates)
    catalogue = Object.new
    catalogue.define_singleton_method(:call) { |_query| candidates }
    catalogue.define_singleton_method(:warnings) { [] }
    series = Object.new
    series.define_singleton_method(:call) { |_query| [] }
    assert_no_difference ['Record.count', 'VideoAsset.count'] do
      EncoderProjects::FilmCatalogue.stub(:new, -> { catalogue }) do
        EncoderProjects::SeriesCatalogueSearch.stub(:new, -> { series }) do
          get encoder_projects_catalogue_path, params: { request_token: @request_token }
        end
      end
    end
  end
end
