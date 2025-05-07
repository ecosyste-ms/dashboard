require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get collections_index_url
    assert_response :success
  end

  test "should get show" do
    get collections_show_url
    assert_response :success
  end

  test "should get adoption" do
    get collections_adoption_url
    assert_response :success
  end

  test "should get engagement" do
    get collections_engagement_url
    assert_response :success
  end

  test "should get dependency" do
    get collections_dependency_url
    assert_response :success
  end

  test "should get productivity" do
    get collections_productivity_url
    assert_response :success
  end

  test "should get finance" do
    get collections_finance_url
    assert_response :success
  end

  test "should get responsiveness" do
    get collections_responsiveness_url
    assert_response :success
  end
end
