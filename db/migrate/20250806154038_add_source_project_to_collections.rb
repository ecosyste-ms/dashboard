class AddSourceProjectToCollections < ActiveRecord::Migration[8.0]
  def change
    add_reference :collections, :source_project, null: true, foreign_key: { to_table: :projects }
  end
end
