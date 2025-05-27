class User < ApplicationRecord
  has_many :collections, dependent: :destroy

  def self.from_omniauth(auth)
    find_or_create_by(provider: auth['provider'], uid: auth['uid']) do |user|
      user.name = auth['info']['name']
      user.email = auth['info']['email']
    end
  end
end
