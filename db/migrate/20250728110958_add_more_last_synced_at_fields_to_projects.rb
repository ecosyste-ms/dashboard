class AddMoreLastSyncedAtFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :commits_last_synced_at, :datetime
    add_column :projects, :packages_last_synced_at, :datetime
    add_column :projects, :dependencies_last_synced_at, :datetime
  end
end
