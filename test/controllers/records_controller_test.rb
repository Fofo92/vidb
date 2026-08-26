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
          language_version_id: @record.language_version_id
        }
      }
    end

    created_record = Record.find_by!(french_title: "Nouveau film")

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
        length_in_mn: 95
      }
    }

    assert_redirected_to record_url(@record)
    assert_equal "Nouveau titre", @record.reload.french_title
    assert_equal 95, @record.length_in_mn
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
end
