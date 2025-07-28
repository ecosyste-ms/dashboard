class AddSyncStatusToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :sync_status, :string, default: "pending", null: false
  end
end
