class AddDependencyCountsToProjects < ActiveRecord::Migration[8.0]
  def change
    add_column :projects, :direct_dependencies_count, :integer, default: 0, null: false
    add_column :projects, :development_dependencies_count, :integer, default: 0, null: false
    add_column :projects, :transitive_dependencies_count, :integer, default: 0, null: false
  end
end
