require 'test_helper'

class SyncCollectionWorkerTest < ActiveSupport::TestCase
  test "should sync collection projects" do
    collection = create(:collection, import_status: 'completed')
    project1 = create(:project)
    project2 = create(:project)
    collection.projects << [project1, project2]

    assert_difference 'SyncProjectWorker.jobs.size', 2 do
      assert_difference 'CheckCollectionSyncStatusWorker.jobs.size', 1 do
        SyncCollectionWorker.new.perform(collection.id)
      end
    end

    collection.reload
    assert_equal 'syncing', collection.sync_status
  end

  test "should handle missing collection" do
    assert_nothing_raised do
      SyncCollectionWorker.new.perform(999999)
    end
  end

  test "should not sync if collection not found" do
    assert_no_difference 'SyncProjectWorker.jobs.size' do
      SyncCollectionWorker.new.perform(999999)
    end
  end
end