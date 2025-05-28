require "test_helper"

class CollectionsControllerTest < ActionDispatch::IntegrationTest
  test "should get index" do
    get collections_url
    assert_response :redirect
    assert_redirected_to login_url
  end
end
