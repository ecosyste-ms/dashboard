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
      # Check if project still exists and hasn't been destroyed
      if !project.destroyed? && project.sync_job_id.present?
        project.update_columns(sync_job_id: nil)
      end
    end
  end
end