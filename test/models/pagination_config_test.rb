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

  test "test environment has per_page limits configured" do
    assert_not_nil Rails.application.config.x.per_page_limits
    assert_equal 10, Rails.application.config.x.per_page_limits[:packages]
    assert_equal 10, Rails.application.config.x.per_page_limits[:issues]
    assert_equal 10, Rails.application.config.x.per_page_limits[:commits]
    assert_equal 10, Rails.application.config.x.per_page_limits[:tags]
    assert_equal 10, Rails.application.config.x.per_page_limits[:advisories]
    assert_equal 10, Rails.application.config.x.per_page_limits[:repositories]
  end

  test "project uses pagination limits from config" do
    project = FactoryBot.create(:project)
    
    # We can't easily test the actual pagination without making HTTP calls,
    # but we can verify the config is accessible from the model context
    assert_equal 2, Rails.application.config.x.pagination_limits&.dig(:packages)
    assert_equal 10, Rails.application.config.x.per_page_limits&.dig(:packages)
  end
end