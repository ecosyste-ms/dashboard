class SyncCollectionWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options queue: 'collection_sync', retry: 3

  def perform(collection_id)
    collection = Collection.find_by_id(collection_id)
    return unless collection

    Rails.logger.info "Starting collection sync for: #{collection.name} (ID: #{collection.id})"
    
    collection.sync_projects
  end
end