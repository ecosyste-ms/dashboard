class DropPackagesFromProjects < ActiveRecord::Migration[7.1]
  def change
    remove_column :projects, :packages, :json, default: []
    remove_column :projects, :package_urls, :string, default: []
  end
end
