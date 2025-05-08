class AddLastSyncedAtFieldsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :issues_last_synced_at, :datetime
    add_column :projects, :tags_last_synced_at, :datetime
  end
end
