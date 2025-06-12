class CollectionSyncChannel < ApplicationCable::Channel
  def subscribed
    collection = Collection.find_by_uuid(params[:collection_id])
    if collection
      Rails.logger.info "CollectionSyncChannel: Subscribed to collection #{collection.id} (#{params[:collection_id]})"
      stream_for collection
    else
      Rails.logger.error "CollectionSyncChannel: Collection not found for UUID #{params[:collection_id]}"
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "CollectionSyncChannel: Unsubscribed from collection #{params[:collection_id]}"
  end
end
