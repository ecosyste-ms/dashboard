class AddMoreFieldsToCollections < ActiveRecord::Migration[8.0]
  def change
    add_column :collections, :github_organization_url, :string
    add_column :collections, :collective_url, :string
    add_column :collections, :github_repo_url, :string
    add_column :collections, :dependency_file, :text
  end
end