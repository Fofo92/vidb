require "test_helper"
require "minitest/mock"

class DvdPreparationsControllerTest < ActionDispatch::IntegrationTest
  include Devise::Test::IntegrationHelpers

  setup do
    @user = User.create!(email: "dvd-preparation@example.com", password: "password")
    sign_in @user
  end

  test "scans survive a later visit without creating a work or a DVD holding" do
    DvdBarcodeLookup.stub(:new, -> { lookup_client(["Code Quantum - Saison 2"]) }) do
      assert_no_difference ["Record.count", "DvdEdition.count", "DvdContent.count"] do
        assert_difference("DvdPreparation.count", 2) do
          post dvd_preparations_path, params: { ean: "5050582454376" }
          post dvd_preparations_path, params: { ean: "3384442021449" }
        end
      end
    end
    get dvd_preparations_path
    assert_response :success
    assert_select "td", text: "5050582454376"
    assert_select "td", text: "3384442021449"
    assert_select "input[name=ean][autofocus]"
    assert_equal ["Code Quantum - Saison 2"], DvdPreparation.find_by!(ean: "5050582454376").external_titles
  end

  test "scanning the same EAN again finds its existing draft and keeps notes" do
    preparation = DvdPreparation.create!(ean: "5050582454376", notes: "Disque 1 à insérer", lookup_status: "found")
    assert_no_difference "DvdPreparation.count" do
      post dvd_preparations_path, params: { ean: preparation.ean }
    end
    assert_redirected_to dvd_preparations_path
    assert_equal "Disque 1 à insérer", preparation.reload.notes
  end

  test "invalid EAN is rejected without external lookup" do
    DvdBarcodeLookup.stub(:new, -> { flunk "No lookup for an invalid code" }) do
      assert_no_difference "DvdPreparation.count" do
        post dvd_preparations_path, params: { ean: "5050582454377" }
      end
    end
    assert_response :unprocessable_content
  end

  test "external lookup failure leaves the scan available for later" do
    client = Object.new
    def client.call(_ean)
      raise DvdBarcodeLookup::Error
    end
    DvdBarcodeLookup.stub(:new, -> { client }) do
      post dvd_preparations_path, params: { ean: "5050582454376" }
    end
    preparation = DvdPreparation.find_by!(ean: "5050582454376")
    assert_equal "unavailable", preparation.lookup_status
    get dvd_preparation_path(preparation)
    assert_response :success
    assert_select "p", text: /Le scan et les informations précédentes sont conservés/
  end

  test "draft edits remain separate from the catalogue and ignore unpermitted identity changes" do
    preparation = DvdPreparation.create!(ean: "5050582454376")
    assert_no_difference ["Record.count", "DvdEdition.count", "DvdContent.count"] do
      patch dvd_preparation_path(preparation), params: { dvd_preparation: {
        provisional_title: "Code Quantum", announced_content_count: 22, notes: "À confirmer sur les disques",
        ean: "3384442021449", lookup_status: "found"
      } }
    end
    assert_redirected_to dvd_preparation_path(preparation)
    assert_equal "Code Quantum", preparation.reload.provisional_title
    assert_equal 22, preparation.announced_content_count
    assert_equal "5050582454376", preparation.ean
    assert_equal "pending", preparation.lookup_status
  end

  test "invalid estimates keep the existing draft and display errors" do
    preparation = DvdPreparation.create!(ean: "5050582454376", announced_content_count: 22)
    patch dvd_preparation_path(preparation), params: { dvd_preparation: { announced_content_count: -1 } }
    assert_response :unprocessable_content
    assert_equal 22, preparation.reload.announced_content_count
    assert_select "p[role=alert]"
  end

  test "refresh is explicit and preserves manual notes" do
    preparation = DvdPreparation.create!(ean: "5050582454376", notes: "Disque 2 manquant")
    DvdBarcodeLookup.stub(:new, -> { lookup_client(["Quantum Leap"]) }) do
      post lookup_dvd_preparation_path(preparation)
    end
    assert_redirected_to dvd_preparation_path(preparation)
    assert_equal "Disque 2 manquant", preparation.reload.notes
    assert_equal "found", preparation.lookup_status
  end

  test "getting a preparation never calls an external service or writes to the database" do
    preparation = DvdPreparation.create!(ean: "5050582454376")
    timestamp = preparation.updated_at
    DvdBarcodeLookup.stub(:new, -> { flunk "GET must not look up a code" }) do
      get dvd_preparation_path(preparation)
    end
    assert_response :success
    assert_equal timestamp, preparation.reload.updated_at
  end

  test "preparations require authentication" do
    sign_out @user
    assert_no_difference "DvdPreparation.count" do
      post dvd_preparations_path, params: { ean: "5050582454376" }
    end
    assert_redirected_to new_user_session_path
  end

  private

  def lookup_client(titles)
    Object.new.tap { |client| client.define_singleton_method(:call) { |_ean| titles } }
  end
end
