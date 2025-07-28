class ProjectSyncChannel < ApplicationCable::Channel
  def subscribed
    project = Project.find_by(id: params[:project_id])
    if project
      Rails.logger.info "ProjectSyncChannel: Subscribed to project #{project.id}"
      stream_for project
    else
      Rails.logger.error "ProjectSyncChannel: Project not found for ID #{params[:project_id]}"
      reject
    end
  end

  def unsubscribed
    Rails.logger.info "ProjectSyncChannel: Unsubscribed from project #{params[:project_id]}"
  end
end