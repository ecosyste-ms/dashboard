class DropCollectivesProjectsTable < ActiveRecord::Migration[7.1]
  def change
    drop_table :collective_projects
  end
end
