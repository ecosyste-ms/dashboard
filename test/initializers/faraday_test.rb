require 'test_helper'

class FaradayTest < ActiveSupport::TestCase
  test "default connection has correct User-Agent header" do
    user_agent = Faraday.default_connection.headers['User-Agent']
    assert_equal 'dashboard.ecosyste.ms', user_agent
  end

  test "default connection has correct timeout settings" do
    options = Faraday.default_connection.options
    assert_equal 10, options.timeout
    assert_equal 10, options.open_timeout
  end
end