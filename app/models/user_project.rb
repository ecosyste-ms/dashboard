class UserProject < ApplicationRecord
  belongs_to :user
  belongs_to :project

  validates :user_id, uniqueness: { scope: :project_id }

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def self.add_project_to_user(user, project)
    # First try to find an existing record (including soft-deleted ones)
    user_project = find_by(user: user, project: project)
    
    if user_project
      # If it exists but is soft-deleted, restore it
      if user_project.deleted?
        user_project.restore!
      end
      user_project
    else
      # Create new record
      create!(user: user, project: project)
    end
  end

  def soft_delete!
    update!(deleted_at: Time.current)
  end

  def restore!
    update!(deleted_at: nil)
  end

  def deleted?
    deleted_at.present?
  end

  def active?
    deleted_at.nil?
  end
end