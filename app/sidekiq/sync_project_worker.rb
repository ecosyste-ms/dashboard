class SyncProjectWorker
  include Sidekiq::Worker
  include Sidekiq::Status::Worker

  def perform(project_id)
    project = Project.find_by_id(project_id)
    return unless project
    
    begin
      project.sync
    ensure
      # Clear the job ID after completion (success or failure)
      project.update_columns(sync_job_id: nil) if project.sync_job_id.present?
    end
  end
end