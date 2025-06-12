class ImportCollectionWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  sidekiq_options queue: 'collection_sync', retry: 3

  def perform(collection_id)
    collection = Collection.find_by_id(collection_id)
    return unless collection
    
    collection.import_projects_sync
  end
end