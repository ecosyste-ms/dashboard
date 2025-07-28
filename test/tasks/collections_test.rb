require 'test_helper'

class CollectionsRakeTest < ActiveSupport::TestCase
  def setup
    Rake::Task.clear
    Rails.application.load_tasks if Rake::Task.tasks.empty?
  end

  test "collections:sync task should sync least recently synced collections" do
    old_collection = create(:collection, last_synced_at: 2.days.ago)
    new_collection = create(:collection, last_synced_at: 1.day.ago)
    never_synced = create(:collection, last_synced_at: nil)
    importing_collection = create(:collection, import_status: 'importing')

    assert_difference 'SyncCollectionWorker.jobs.size', 4 do
      Rake::Task['collections:sync'].invoke
    end

    # Should sync all collections, prioritizing never synced and oldest first
  end

  test "collections:sync task should respect limit" do
    15.times do |i|
      create(:collection, last_synced_at: i.days.ago)
    end

    assert_difference 'SyncCollectionWorker.jobs.size', 10 do
      Rake::Task['collections:sync'].invoke
    end
  end
end