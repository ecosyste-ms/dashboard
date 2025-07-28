require 'test_helper'

class SyncCollectionWorkerTest < ActiveSupport::TestCase
  test "should sync collection projects" do
    collection = create(:collection, import_status: 'completed')
    project1 = create(:project, sync_status: 'pending', last_synced_at: nil)
    project2 = create(:project, sync_status: 'pending', last_synced_at: nil)
    collection.projects << [project1, project2]

    # Mock the GitHub org API response to prevent actual network calls
    stub_request(:get, /repos\.ecosyste\.ms.*testorg.*repositories/)
      .to_return(status: 200, body: [].to_json)

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