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

    %w[is_recorded is_seen is_available is_checked].each do |attribute|
      assert_select(
        "input[type='checkbox'][name='record[#{attribute}]']:not([checked])"
      )
    end
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

  test "displays the immediate hierarchy placement diagnosis" do
    expected_presentations = [
      ["undetermined", "undetermined", "À déterminer", "text-bg-warning"],
      ["standalone_video", "consistent", "Conforme", "text-bg-success"],
      ["season", "inconsistent", "Incohérent", "text-bg-danger"]
    ]

    expected_presentations.each do |record_kind, status, label, badge_class|
      @record.update!(record_kind: record_kind)

      get record_url(@record)

      assert_response :success
      assert_select(
        "[data-hierarchy-placement-status='#{status}']" \
        "[title='Diagnostic du placement de cette fiche par rapport " \
        "à son parent immédiat ou à la racine ; il ne porte pas " \
        "sur ses descendants']"
      ) do
        assert_select "strong", text: /placement de cette fiche/i
        assert_select ".badge.#{badge_class}", text: label
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
      %w[undetermined standalone_video series],
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
end
