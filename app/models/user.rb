class User < ApplicationRecord
  has_many :collections, dependent: :destroy
  has_many :user_projects, dependent: :destroy
  has_many :projects, through: :user_projects

  def self.from_omniauth(auth)
    find_or_create_by(provider: auth['provider'], uid: auth['uid']) do |user|
      user.name = auth['info']['name']
      user.email = auth['info']['email']
    end
  end

  def avatar_url
    "https://avatars.githubusercontent.com/u/#{uid}?v=4"
  end

  def has_project?(project)
    user_projects.active.where(project: project).exists?
  end
end
