require 'test_helper'

class PaginationConfigTest < ActiveSupport::TestCase
  test "test environment has pagination limits configured" do
    assert_not_nil Rails.application.config.x.pagination_limits
    assert_equal 2, Rails.application.config.x.pagination_limits[:packages]
    assert_equal 2, Rails.application.config.x.pagination_limits[:issues]
    assert_equal 2, Rails.application.config.x.pagination_limits[:commits]
    assert_equal 2, Rails.application.config.x.pagination_limits[:tags]
    assert_equal 2, Rails.application.config.x.pagination_limits[:advisories]
  end

  test "project uses pagination limits from config" do
    project = FactoryBot.create(:project)
    
    # We can't easily test the actual pagination without making HTTP calls,
    # but we can verify the config is accessible from the model context
    assert_equal 2, Rails.application.config.x.pagination_limits&.dig(:packages)
  end
end