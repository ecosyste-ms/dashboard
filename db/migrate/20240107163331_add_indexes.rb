class AddIndexes < ActiveRecord::Migration[7.1]
  def change
    add_index :projects, :url, unique: true
    add_index :collectives, :slug, unique: true
    add_index :collective_projects, :project_id
    add_index :collective_projects, :collective_id
  end
end
