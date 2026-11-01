require "test_helper"

class RecordsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    user = User.create!(
      email: "test@example.com",
      password: "password"
    )
    sign_in user

    language_version = LanguageVersion.create!(
      short_name: "VF",
      long_name: "Version française"
    )

    @record = Record.create!(
      french_title: "Ancien titre",
      length_in_mn: 90,
      language_version: language_version
    )
  end

  test "creates a root record" do
    assert_difference("Record.count", 1) do
      post records_url, params: {
        record: {
          french_title: "Nouveau film",
          length_in_mn: 110,
          record_kind: "standalone_video",
          language_version_id: @record.language_version_id
        }
      }
    end

    created_record = Record.find_by!(french_title: "Nouveau film")

    assert created_record.record_kind_standalone_video?
    assert created_record.root?
    assert_redirected_to record_url(created_record)
  end

  test "creates a child record and redirects to its parent" do
    assert_difference("Record.count", 1) do
      post records_url, params: {
        record: {
          french_title: "Nouvel épisode",
          length_in_mn: 45,
          language_version_id: @record.language_version_id,
          parent_id: @record.id
        }
      }
    end

    created_record = Record.find_by!(french_title: "Nouvel épisode")

    assert_equal @record, created_record.parent
    assert_redirected_to record_url(@record)
  end

  test "displays the hierarchy error after rejecting a child creation" do
    @record.update!(record_kind: "standalone_video")

    assert_no_difference("Record.count") do
      post records_url, params: {
        record: {
          french_title: "Épisode impossible",
          record_kind: "episode",
          language_version_id: @record.language_version_id,
          parent_id: @record.id
        }
      }
    end

    assert_response :unprocessable_content
    assert_select(
      ".record_parent_id .invalid-feedback",
      text: /ne permet pas ce placement pour la nature du contenu/
    )
  end

  test "redisplays the child form after invalid child creation" do
    assert_no_difference("Record.count") do
      post records_url, params: {
        record: {
          french_title: "",
          original_title: "",
          language_version_id: @record.language_version_id,
          parent_id: @record.id
        }
      }
    end

    assert_response :unprocessable_content
    assert_select(
      "a[href='#{record_path(@record)}']",
      text: /Retour/
    )
  end

  test "rejects a root record creation with invalid attributes" do
    assert_no_difference("Record.count") do
      post records_url, params: {
        record: {
          french_title: "",
          original_title: "",
          language_version_id: @record.language_version_id
        }
      }
    end

    assert_response :unprocessable_content
  end

  test "updates a record with valid attributes" do
    patch record_url(@record), params: {
      record: {
        french_title: "Nouveau titre",
        length_in_mn: 95,
        record_kind: "series"
      }
    }

    assert_redirected_to record_url(@record)

    @record.reload

    assert_equal "Nouveau titre", @record.reload.french_title
    assert_equal 95, @record.length_in_mn
    assert @record.record_kind_series?
  end

  test "manual summary edits are protected and provenance parameters cannot forge an external origin" do
    patch record_url(@record), params: {
      record: { abstract: "Résumé rédigé ici", abstract_provenance: { kind: "external" } }
    }
    assert_redirected_to record_url(@record)
    assert_equal "Résumé rédigé ici", @record.reload.abstract
    assert_equal "manual", @record.abstract_provenance["kind"]
    assert @record.abstract_protected?

    patch record_url(@record), params: { record: { abstract: "" } }
    assert_redirected_to record_url(@record)
    assert_equal "", @record.reload.abstract
    assert @record.abstract_protected?
  end

  test "the edit form explains summary protection" do
    get edit_record_url(@record)
    assert_response :success
    assert_select "[data-record-abstract-protection]", text: /supprimé manuellement/
  end

  test "rejects a record update with invalid attributes" do
    patch record_url(@record), params: {
      record: {
        french_title: "",
        original_title: ""
      }
    }

    assert_response :unprocessable_content
    assert_equal "Ancien titre", @record.reload.french_title
  end

  test "destroys a root record" do
    assert_difference("Record.count", -1) do
      delete record_url(@record)
    end

    assert_redirected_to records_url
  end

  test "redirects to the parent after destroying a child record" do
    child = @record.children.create!(
      french_title: "Épisode",
      length_in_mn: 45,
      language_version: @record.language_version
    )

    assert_difference("Record.count", -1) do
      delete record_url(child)
    end

    assert_redirected_to record_url(@record)
  end

  test "searches records by french title" do
    other_record = Record.create!(
      french_title: "Film sans rapport",
      language_version: @record.language_version
    )

    get records_url, params: {
      q: {
        french_title_cont: "Ancien"
      }
    }

    assert_response :success
    assert_select "a[href='#{record_path(@record)}']", text: "Ancien titre"
    assert_select "a[href='#{record_path(other_record)}']", count: 0
  end

  test "searches records by french or original title" do
    matching_record = Record.create!(
      french_title: "Titre français distinct",
      original_title: "The Hidden Film",
      language_version: @record.language_version
    )

    get records_url, params: {
      q: {
        french_title_or_original_title_cont: "Hidden"
      }
    }

    assert_response :success
    assert_select(
      "a[href='#{record_path(matching_record)}']",
      text: "Titre français distinct (The Hidden Film)"
    )
    assert_select "a[href='#{record_path(@record)}']", count: 0
  end

  test "filters the index by country and keeps the selected criteria" do
    country = Country.create!(short_name: "AU", long_name: "Australie filtre index")
    @record.countries << country
    get records_url, params: { filters: { country_id: country.id, display: "matches" } }

    assert_response :success
    assert_select "[data-record-filters]"
    assert_select "#filters_country_id option[selected][value='#{country.id}']"
    assert_select "[data-record-state-row='#{@record.id}']"
  end

  test "shows the selected tree and provides its child qualification link" do
    @record.update!(record_kind: "series")
    child = @record.children.create!(french_title: "Enfant filtre index", record_kind: "season",
                                     language_version: @record.language_version)
    get records_url, params: { filters: { tree_id: @record.id } }

    assert_response :success
    assert_select "[data-record-state-row='#{@record.id}']"
    assert_select "[data-record-state-row='#{child.id}']"
    assert_select "a[href='#{edit_record_child_qualification_path(@record)}']"
  end

  test "prefills a new child with its parent associations" do
    language_version = LanguageVersion.create!(
      short_name: "VO",
      long_name: "Version originale"
    )
    gender = Gender.create!(name: "Policier")
    country = Country.create!(
      short_name: "GB",
      long_name: "Royaume-Uni"
    )
    medium = Medium.create!(
      short_name: "HD",
      long_name: "Hard Disk Drive"
    )

    @record.update!(language_version: language_version)
    @record.genders << gender
    @record.countries << country
    @record.media << medium

    get new_child_record_url(@record)

    assert_response :success
    assert_select(
      "input[type='hidden'][name='record[parent_id]'][value='#{@record.id}']"
    )
    assert_select "[data-record-parent]" do
      assert_select(
        "a[href='#{record_path(@record)}']",
        text: @record.complete_title
      )
    end
    assert_select(
      "select[name='record[gender_ids][]'] option[selected][value='#{gender.id}']"
    )
    assert_select(
      "select[name='record[country_ids][]'] option[selected][value='#{country.id}']"
    )
    assert_select(
      "input[type='checkbox'][name='record[medium_ids][]'][value='#{medium.id}'][checked]"
    )
    assert_select(
      "select[name='record[language_version_id]'] option[selected][value='#{language_version.id}']"
    )
  end

  test "does not inherit parent states when preparing a child" do
    @record.update!(
      is_recorded: true,
      is_seen: true,
      is_available: true,
      is_checked: true
    )

    get new_child_record_url(@record)

    assert_response :success

    %w[is_recorded is_seen is_available].each do |attribute|
      assert_select(
        "input[type='checkbox'][name='record[#{attribute}]']:not([checked])"
      )
    end
    assert_select "input[name='record[is_checked]']", count: 0
  end

  test "displays child records ordered by rank" do
    @record.children.create!(
      french_title: "Deuxième élément",
      rank: 2,
      language_version: @record.language_version
    )
    @record.children.create!(
      french_title: "Premier élément",
      rank: 1,
      language_version: @record.language_version
    )

    get record_url(@record)

    assert_response :success

    assert_select "tbody tr td:nth-child(3) a" do |links|
      assert_equal(
        ["Premier élément", "Deuxième élément"],
        links.map { |link| link.text.strip }
      )
    end
  end

  test "displays the record kind on the record page" do
    @record.update!(record_kind: "standalone_video")

    get record_url(@record)

    assert_response :success
    assert_select "[data-record-kind]", text: /Vidéo autonome/
  end

  test "displays the immediate hierarchy placement diagnosis with the content kind" do
    expected_presentations = [
      ["undetermined", "undetermined", "À déterminer"],
      ["standalone_video", "consistent", "Conforme"],
      ["season", "inconsistent", "Incohérent"]
    ]

    expected_presentations.each do |record_kind, status, label|
      @record.update!(record_kind: record_kind)
      get record_url(@record)

      assert_response :success
      assert_select "[data-record-kind][data-hierarchy-placement-status='#{status}']" do |nodes|
        assert_includes nodes.first['class'], "record-show-nature--#{status}"
        assert_equal "Placement : #{label}", nodes.first['title']
      end
    end
  end

  test "offers only root-compatible kinds for a new root record" do
    get new_record_url

    assert_response :success

    option_values = css_select(
      "select[name='record[record_kind]'] option"
    ).map { |option| option["value"] }

    assert_equal(
      %w[undetermined standalone_video collection series],
      option_values
    )
  end

  test "offers kinds compatible with the new child's parent" do
    expected_kinds_by_parent_kind = {
      "undetermined" => %w[
        undetermined
        standalone_video
        season
        episode
      ],
      "series" => %w[
        undetermined
        season
        episode
      ],
      "season" => %w[
        undetermined
        episode
      ]
    }

    expected_kinds_by_parent_kind.each do |parent_kind, expected_kinds|
      @record.update!(record_kind: parent_kind)

      get new_child_record_url(@record)

      assert_response :success

      option_values = css_select(
        "select[name='record[record_kind]'] option"
      ).map { |option| option["value"] }

      assert_equal(
        expected_kinds,
        option_values,
        "Unexpected choices for a child of #{parent_kind}"
      )
    end
  end

  test "offers every kind when editing an existing record" do
    get edit_record_url(@record)

    assert_response :success

    option_values = css_select(
      "select[name='record[record_kind]'] option"
    ).map { |option| option["value"] }

    assert_equal(
      %w[
        undetermined
        standalone_video
        collection
        series
        season
        episode
      ],
      option_values
    )
  end

  test "offers child creation only to records that may contain children" do
    expected_link_counts = {
      "undetermined" => 1,
      "series" => 1,
      "season" => 1,
      "standalone_video" => 0,
      "episode" => 0
    }

    expected_link_counts.each do |record_kind, expected_count|
      @record.update!(record_kind: record_kind)

      get record_url(@record)

      assert_response :success
      assert_select(
        "a[href='#{new_child_record_path(@record)}']",
        count: expected_count
      )
    end
  end

  test "does not display a parent field for a new root record" do
    get new_record_url

    assert_response :success
    assert_select "input[name='record[parent_id]']", count: 0
    assert_select "[data-record-parent]", count: 0
  end

  test "displays an existing parent without allowing ordinary reassignment" do
    child = @record.children.create!(
      french_title: "Épisode",
      language_version: @record.language_version
    )

    get edit_record_url(child)

    assert_response :success
    assert_select "input[name='record[parent_id]']", count: 0
    assert_select "[data-record-parent]" do
    assert_select(
      "a[href='#{record_path(@record)}']",
      text: @record.complete_title
    )
    end
  end

  test "offers the dedicated hierarchy move page" do
  get record_url(@record)

  assert_response :success
  assert_select(
    "a[href='#{edit_record_hierarchy_placement_path(@record)}']",
    text: /Déplacer/
  )
  end

  test "offers bulk child qualification for a record with children" do
    @record.children.create!(
      french_title: "Enfant à qualifier",
      record_kind: "undetermined",
      language_version: @record.language_version
    )

    get record_url(@record)

    assert_response :success
    assert_select(
      "a[href='#{edit_record_child_qualification_path(@record)}']",
      text: /Qualifier les enfants/
    )
  end

  test "offers metadata qualification even without a compatible kind" do
    @record.children.create!(
      french_title: "Enfant historique",
      record_kind: "undetermined",
      language_version: @record.language_version
    )

    @record.update!(record_kind: "standalone_video")

    get record_url(@record)

    assert_response :success
    assert_select(
      "a[href='#{edit_record_child_qualification_path(@record)}']",
      count: 1
    )
  end

  test "show separates editorial information from viewing and copies" do
    @record.update!(record_kind: "standalone_video", year: 2023, abstract: "Présentation de l’œuvre.")
    before = @record.attributes.deep_dup
    get record_url(@record)

    assert_response :success
    assert_select "[data-record-overview] #record-title", text: /Ancien titre/
    assert_select "[data-record-overview] .record-show-abstract", text: "Présentation de l’œuvre."
    assert_select "[data-record-overview] [data-copy-duration='#{@record.id}']", count: 1
    assert_select "[data-record-information] [data-record-state-summary]", count: 0
    assert_select "[data-record-viewing] [data-record-state-summary='#{@record.id}']", count: 1
    assert_select "[data-record-viewing] [data-copy-supports='#{@record.id}']", count: 1
    assert_select "[data-record-viewing] [data-copy-languages='#{@record.id}']", count: 1
    assert_select "[data-record-copy-details]", count: 0
    assert_equal before, @record.reload.attributes
  end

  test "copy paths and technical details remain accessible inside a closed disclosure" do
    @record.update!(record_kind: "standalone_video")
    asset = @record.video_assets.create!(status: "present", last_known_path: "/videos/Film de test.mkv",
                                         duration_minutes: 90, language_version: @record.language_version)
    get record_url(@record)

    assert_response :success
    assert_select "[data-record-viewing] details[data-record-copy-details]:not([open])" do
      assert_select "summary", text: "Détails des copies"
      assert_select "[data-confirmed-video-assets] [data-video-asset='#{asset.id}']", count: 1
      assert_select "[data-copy-path]", text: "/videos/Film de test.mkv"
    end
    assert_select "[data-record-information] [data-confirmed-video-assets]", count: 0
  end

  test "season presentation stays optional and collapsed in the editorial section" do
    @record.update!(record_kind: "series")
    season = @record.children.create!(french_title: "Saison 01", record_kind: "season", rank: 1,
                                      abstract: "Présentation propre à cette saison.",
                                      language_version: @record.language_version)
    get record_url(season)

    assert_response :success
    assert_select "[data-record-overview] details[data-season-presentation]:not([open])" do
      assert_select "summary", text: "Présentation de cette saison"
      assert_select "p", text: "Présentation propre à cette saison."
    end
  end


  test "show explicitly loads its stylesheet and keeps a poster slot without an image" do
    get record_url(@record)

    assert_response :success
    assert_select "head link[rel='stylesheet'][href*='record_show']", count: 1
    assert_select "[data-record-overview] .record-show-artwork [data-record-poster-placeholder]", count: 1
    assert_select "[data-record-poster]", count: 0
    assert_select "[data-record-poster-controls]", count: 1
    assert_select "[data-record-overview] .record-show-content [data-record-viewing]", count: 1
  end


  test "show presents a plain year and compact values without catalogue suffixes" do
    @record.update!(record_kind: "standalone_video", year: 1962, length_in_mn: 105)
    get record_url(@record)

    assert_response :success
    assert_select "[data-record-information] [data-record-year='#{@record.id}']", text: "1962"
    assert_select "[data-record-information] .record-show-facts small", count: 0
    assert_select "[data-copy-duration='#{@record.id}']", text: "01h45"
    assert_select "[data-record-information] .record-show-facts", text: /catalogue|\?/, count: 0
    assert_select "[data-record-viewing] [data-copy-languages='#{@record.id}']", text: "VF"
    assert_select "[data-record-poster-controls]", text: /Les images personnelles|Ce produit utilise/, count: 0
    assert_select "a[href='#{credits_path}']", text: "Crédits"
  end

  test "show prefers the measured copy duration over the reference duration" do
    @record.update!(record_kind: "standalone_video", length_in_mn: 90)
    @record.video_assets.create!(status: "present", last_known_path: "/videos/Film mesuré.mkv",
                                 duration_minutes: 105, language_version: @record.language_version)
    get record_url(@record)

    assert_response :success
    assert_select "[data-record-information] [data-copy-duration='#{@record.id}']", text: "01:45"
  end

  test "credits are available separately from the poster controls" do
    get credits_path
    assert_response :success
    assert_select "h1", text: "Crédits"
    assert_select "p[lang='en']", text: /This product uses the TMDB API/
  end


  test "show places the year with the French title and separates the original title" do
    @record.update!(record_kind: "standalone_video", french_title: "Titre français",
                     original_title: "Original title", year: 1962)
    get record_url(@record)

    assert_response :success
    assert_select "h1#record-title [data-record-main-title]", text: "Titre français"
    assert_select "h1#record-title .record-show-year [data-record-year]", text: "1962"
    assert_select "h1#record-title", text: /Original title/, count: 0
    assert_select "[data-record-original-title]", text: "Original title"
    assert_select "[data-record-breadcrumbs] [aria-current='page']", text: "Titre français (Original title)"
  end

  test "production countries are alphabetized in the compact facts" do
    @record.update!(record_kind: "standalone_video")
    @record.countries << Country.create!(short_name: "ZM", long_name: "Zambie")
    @record.countries << Country.create!(short_name: "US", long_name: "États-Unis")
    get record_url(@record)

    assert_response :success
    assert_select ".record-show-facts dd", text: "États-Unis, Zambie"
  end

end
