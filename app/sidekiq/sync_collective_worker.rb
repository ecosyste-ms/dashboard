class SyncCollectiveWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(collective_id)
    Collective.find_by_id(collective_id).try(:sync)
  end
end