class AddSoftDeleteToCollectionProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :collection_projects, :deleted_at, :datetime
    add_timestamps :collection_projects, null: true
    add_index :collection_projects, :deleted_at
    add_index :collection_projects, [:collection_id, :project_id], unique: true
  end
end
