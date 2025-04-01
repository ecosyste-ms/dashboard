class AddCollectiveIdToProjects < ActiveRecord::Migration[7.1]
  def change
    add_column :projects, :collective_id, :integer
    add_index :projects, :collective_id
  end
end
