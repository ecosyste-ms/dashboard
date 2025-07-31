class UserProject < ApplicationRecord
  belongs_to :user
  belongs_to :project

  enum :status, { active: 0, removed: 1 }

  validates :user_id, uniqueness: { scope: :project_id }

  def self.add_project_to_user(user, project)
    find_or_create_by(user: user, project: project) do |user_project|
      user_project.status = :active
    end
  end

  def soft_delete!
    update!(status: :removed)
  end

  def restore!
    update!(status: :active)
  end
end