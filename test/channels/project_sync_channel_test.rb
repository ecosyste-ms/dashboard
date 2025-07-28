require "test_helper"

class ProjectSyncChannelTest < ActionCable::Channel::TestCase
  test "subscribes to project" do
    project = create(:project)
    
    subscribe project_id: project.id
    
    assert subscription.confirmed?
    assert_has_stream_for project
  end

  test "rejects subscription with invalid project id" do
    subscribe project_id: 99999
    
    assert subscription.rejected?
  end
end