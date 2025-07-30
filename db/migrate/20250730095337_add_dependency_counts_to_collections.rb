class AddDependencyCountsToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :direct_dependencies_count, :integer, default: 0, null: false
    add_column :collections, :development_dependencies_count, :integer, default: 0, null: false
    add_column :collections, :transitive_dependencies_count, :integer, default: 0, null: false
  end
end
