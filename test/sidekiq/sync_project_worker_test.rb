require 'test_helper'

class SyncProjectWorkerTest < ActiveSupport::TestCase
  test "should sync project" do
    project = create(:project, sync_job_id: 'test-job-123')
    
    Project.any_instance.expects(:sync).once
    
    SyncProjectWorker.new.perform(project.id)
    
    project.reload
    assert_nil project.sync_job_id
  end
  
  test "should handle missing project" do
    assert_nothing_raised do
      SyncProjectWorker.new.perform(999999)
    end
  end
  
  test "should handle destroyed project during sync" do
    project = create(:project, sync_job_id: 'test-job-123', url: 'https://github.com/test/repo')
    
    # Simulate project being destroyed during sync (e.g., due to duplicate URL)
    Project.any_instance.expects(:sync).once.with do
      project.destroy
      true
    end
    
    assert_nothing_raised do
      SyncProjectWorker.new.perform(project.id)
    end
    
    # Verify the project was destroyed and no update_columns was attempted
    assert project.destroyed?
  end
  
  test "should clear sync_job_id even if sync fails" do
    project = create(:project, sync_job_id: 'test-job-123')
    
    # Simulate sync raising an error
    Project.any_instance.expects(:sync).once.raises(StandardError, "Sync failed")
    
    assert_raises(StandardError) do
      SyncProjectWorker.new.perform(project.id)
    end
    
    project.reload
    assert_nil project.sync_job_id
  end
  
  test "should not clear sync_job_id if already nil" do
    project = create(:project, sync_job_id: nil)
    
    Project.any_instance.expects(:sync).once
    # Should not call update_columns since sync_job_id is already nil
    project.expects(:update_columns).never
    
    SyncProjectWorker.new.perform(project.id)
  end
end