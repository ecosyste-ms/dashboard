class AddFieldsToCollectives < ActiveRecord::Migration[8.0]
  def change
    add_column :collectives, :github_organization_url, :string
    add_column :collectives, :collective_url, :string
    add_column :collectives, :github_repo_url, :string
    add_column :collectives, :dependency_file, :text
  end
end