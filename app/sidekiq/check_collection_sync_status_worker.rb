class CheckCollectionSyncStatusWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options queue: 'collection_sync', retry: 1

  def perform(collection_id)
    collection = Collection.find_by_id(collection_id)
    return unless collection
    
    # Only check if we're in syncing state
    return unless collection.sync_status == 'syncing'
    
    # This will broadcast progress or mark as complete
    collection.check_and_update_sync_status
    
    # If still syncing, check again in 10 seconds for more responsive updates
    if collection.sync_status == 'syncing'
      CheckCollectionSyncStatusWorker.perform_in(10.seconds, collection_id)
    end
  end
end