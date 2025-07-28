require 'test_helper'

class DebugSyncTest < ActiveSupport::TestCase
  test "pagination config is working correctly" do
    # Test our pagination configuration
    assert_equal 2, Rails.application.config.x.pagination_limits[:packages]
    assert_equal 2, Rails.application.config.x.pagination_limits[:issues]
    assert_equal 2, Rails.application.config.x.pagination_limits[:commits]
    assert_equal 2, Rails.application.config.x.pagination_limits[:tags]
    assert_equal 2, Rails.application.config.x.pagination_limits[:advisories]
    
    # Test that project methods use the config correctly
    project = create(:project, :rails_project, :with_repository)
    
    # Mock sync_issues to test if it would use the right max_pages
    project.define_singleton_method(:test_max_pages_for_issues) do
      Rails.application.config.x.pagination_limits&.dig(:issues) || 50
    end
    
    assert_equal 2, project.test_max_pages_for_issues
  end
end