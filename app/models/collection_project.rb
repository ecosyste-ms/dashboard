class CollectionProject < ApplicationRecord
  belongs_to :collection
  belongs_to :project

  validates :collection_id, uniqueness: { scope: :project_id }

  scope :active, -> { where(deleted_at: nil) }
  scope :deleted, -> { where.not(deleted_at: nil) }

  def self.add_project_to_collection(collection, project)
    # First try to find an existing record (including soft-deleted ones)
    collection_project = find_by(collection: collection, project: project)
    
    if collection_project
      # If it exists but is soft-deleted, restore it
      if collection_project.deleted?
        collection_project.restore!
      end
      collection_project
    else
      # Create new record
      create!(collection: collection, project: project)
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
