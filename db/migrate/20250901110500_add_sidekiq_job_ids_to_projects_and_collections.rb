class AddSidekiqJobIdsToProjectsAndCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :sync_job_id, :string
    add_column :collections, :sync_job_id, :string
    
    add_index :projects, :sync_job_id
    add_index :collections, :sync_job_id
  end
end
