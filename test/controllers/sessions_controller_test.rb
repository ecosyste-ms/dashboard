require "test_helper"

class SessionsControllerTest < ActionDispatch::IntegrationTest
  setup do
    @user = create(:user)
  end

  test "should show login page" do
    get login_path
    assert_response :success
  end

  test "should handle authentication failure" do
    get auth_failure_path, params: { message: 'invalid_credentials' }
    
    assert_redirected_to root_path
    assert_equal 'Auth failed', flash[:alert]
  end

  test "should log authentication failure" do
    # Capture logs
    Rails.logger.expects(:warn).with("OmniAuth failure: invalid_credentials")
    
    get auth_failure_path, params: { message: 'invalid_credentials' }
    
    assert_redirected_to root_path
    assert_equal 'Auth failed', flash[:alert]
  end

  test "should destroy session on logout" do  
    get logout_path
    
    assert_redirected_to root_path
    assert_equal 'Signed out!', flash[:notice]
  end

  test "should handle different failure messages" do
    ['access_denied', 'invalid_request', 'server_error'].each do |error_message|
      Rails.logger.expects(:warn).with("OmniAuth failure: #{error_message}")
      
      get auth_failure_path, params: { message: error_message }
      
      assert_redirected_to root_path
      assert_equal 'Auth failed', flash[:alert]
    end
  end

  test "should redirect to login for protected resources" do
    # Try to access collections (requires authentication)
    get collections_path
    assert_redirected_to login_path
  end

  test "should have correct route structure" do
    assert_routing({ method: 'get', path: '/login' }, { controller: 'sessions', action: 'new' })
    assert_routing({ method: 'get', path: '/auth/failure' }, { controller: 'sessions', action: 'failure' })
    assert_routing({ method: 'get', path: '/logout' }, { controller: 'sessions', action: 'destroy' })
  end
end